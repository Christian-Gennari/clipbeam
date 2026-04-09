-- clipbeam - Beam clipboard images from Windows to a remote server via SSH
-- Zero dependencies beyond what Windows and Ubuntu already ship
--
-- This is the STABLE screenshot-only version.
-- Future versions will add support for copied image files.
--
-- Usage in your wezterm.lua:
--   local clipbeam = require("plugins.clipbeam")
--   local keybinding = clipbeam.setup({
--     host = "dev@omenhub",  -- required: SSH destination (user@host or alias)
--     max_dimension = 3840,   -- optional: max width/height (default: 3840 = 4K)
--     remote_path = "~/.clipbeam/paste.png", -- optional: where to save (default: ~/.clipbeam/paste.png)
--     copy_file_path = true,   -- optional: auto-paste path after upload (default: true)
--     notify_on_success = false, -- optional: show toast on success (default: false)
--   })
--   table.insert(config.keys, keybinding)

local wezterm = require("wezterm")

local M = {}

-- Default configuration
local DEFAULT_CONFIG = {
  max_dimension = 3840,
  remote_path = "~/.clipbeam/paste.png",
  copy_file_path = true,
  notify_on_success = false,
}

-- Build the PowerShell script to capture clipboard screenshot as base64
local function build_powershell_script(max_dimension)
  return string.format([[
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Check if clipboard contains image data
    if (-not [System.Windows.Forms.Clipboard]::ContainsImage()) {
      Write-Error "No image in clipboard. Take a screenshot first (Win+Shift+S)."
      exit 1
    }

    # Get the image from clipboard
    $img = [System.Windows.Forms.Clipboard]::GetImage()
    
    # Resize if larger than max dimension while preserving aspect ratio
    $maxDim = %d
    $width = $img.Width
    $height = $img.Height

    if ($width -gt $maxDim -or $height -gt $maxDim) {
      $ratio = [Math]::Min($maxDim / $width, $maxDim / $height)
      $newWidth = [int]($width * $ratio)
      $newHeight = [int]($height * $ratio)

      $resized = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
      $graphics = [System.Drawing.Graphics]::FromImage($resized)
      $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.DrawImage($img, 0, 0, $newWidth, $newHeight)
      $graphics.Dispose()
      $img.Dispose()
      $img = $resized
    }

    # Save to memory stream as PNG
    $stream = New-Object System.IO.MemoryStream
    $img.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $img.Dispose()

    # Convert to base64 and output to stdout
    $bytes = $stream.ToArray()
    $stream.Dispose()
    [Convert]::ToBase64String($bytes)
  ]], max_dimension)
end

-- Execute PowerShell to capture clipboard image as base64
local function capture_clipboard_base64(max_dimension)
  local ps_script = build_powershell_script(max_dimension)

  local success, stdout, stderr = wezterm.run_child_process({
    "powershell.exe",
    "-NoProfile",
    "-NonInteractive",
    "-Command",
    ps_script,
  })

  if not success then
    return nil, "Failed to capture clipboard: " .. (stderr or "unknown error")
  end

  -- Remove trailing whitespace/newlines
  local base64_data = stdout:gsub("%%s+$", "")

  if #base64_data == 0 then
    return nil, "No image data received from clipboard"
  end

  return base64_data, nil
end

-- Transfer image to remote server via SSH using temp file
local function transfer_to_remote(host, remote_path, base64_data)
  -- 1. Extract the remote directory path in Lua (bypasses Windows/Linux path bugs completely)
  local remote_dir = remote_path:match("^(.*)/")
  if not remote_dir then
    remote_dir = "."
  end

  -- Generate temp file paths
  local temp_dir = os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
  local timestamp = tostring(os.time())
  local temp_file = temp_dir .. "/clipbeam_" .. timestamp .. ".b64"
  local ps_script_file = temp_dir .. "/clipbeam_" .. timestamp .. ".ps1"

  -- Write base64 data to temp file
  local f, err = io.open(temp_file, "w")
  if not f then
    return false, "Failed to create temp file: " .. (err or "unknown error")
  end
  f:write(base64_data)
  f:close()

  -- 2. Build a highly-simplified PS1 script using basic string concatenation
  local ps_script = string.format([[
$tempFile = '%s'
$sshHost = '%s'
$remotePath = '%s'
$remoteDir = '%s'

# Replace tilde (~) with `$HOME` so it expands correctly in Bash
$linuxPath = $remotePath -replace '^~/', "`$HOME/"
$linuxDir = $remoteDir -replace '^~/', "`$HOME/"

# Make Linux print "CLIPBEAM_OK" if the directory creation and decoding succeed
$linuxCmd = 'mkdir -p "' + $linuxDir + '" && base64 -d > "' + $linuxPath + '" && echo "CLIPBEAM_OK"'

# Execute the command and let stdout bubble up naturally
cmd.exe /c "ssh -q -o BatchMode=yes -o ConnectTimeout=10 $sshHost `"$linuxCmd`" < `"$tempFile`""
  ]], temp_file, host, remote_path, remote_dir)

  local ps_f, ps_err2 = io.open(ps_script_file, "w")
  if not ps_f then
    os.remove(temp_file)
    return false, "Failed to create PS1 script: " .. (ps_err2 or "unknown error")
  end
  ps_f:write(ps_script)
  ps_f:close()

  -- 3. Execute the PS1 file cleanly
  local success, stdout, stderr = wezterm.run_child_process({
    "powershell.exe",
    "-ExecutionPolicy", "Bypass",
    "-NoProfile",
    "-NonInteractive",
    "-File",
    ps_script_file,
  })

  -- Cleanup both temp files
  os.remove(temp_file)
  os.remove(ps_script_file)

  if not success then
    return false, "SSH transfer failed: " .. (stderr or "unknown error")
  end

  -- Check if Linux explicitly reported success
  wezterm.log_info("clipbeam stdout: [" .. stdout .. "]")  -- DEBUG: show raw stdout
  if not stdout:match("CLIPBEAM_OK") then
    return false, "Failed to decode image on remote server."
  end

  return true, nil
end

-- Main setup function
-- @param opts: Clipbeam configuration options
-- @return: Keybinding table for manual insertion into config.keys
function M.setup(opts)
  if not opts then
    error("clipbeam.setup(): 'opts' is required", 2)
  end
  
  if not opts.host then
    error("clipbeam.setup(): 'opts.host' is required (e.g., 'dev@omenhub' or '192.168.1.50')", 2)
  end

  -- Merge with defaults
  local clipbeam_config = {
    host = opts.host,
    max_dimension = opts.max_dimension or DEFAULT_CONFIG.max_dimension,
    remote_path = opts.remote_path or DEFAULT_CONFIG.remote_path,
    copy_file_path = opts.copy_file_path ~= false, -- default true
    notify_on_success = opts.notify_on_success == true, -- default false
  }

  -- Register the clipbeam event handler
  wezterm.on("clipbeam", function(window, pane)
    -- Step 1: Capture clipboard image as base64
    local base64_data, err = capture_clipboard_base64(clipbeam_config.max_dimension)
    if not base64_data then
      wezterm.log_error("clipbeam: " .. err)
      window:toast_notification("clipbeam", err, nil, 4000)
      return
    end

    -- Step 2: Transfer to remote server
    local success, err = transfer_to_remote(clipbeam_config.host, clipbeam_config.remote_path, base64_data)
    if not success then
      wezterm.log_error("clipbeam: " .. err)
      window:toast_notification("clipbeam", err, nil, 4000)
      return
    end

    -- Step 3: Type the remote path into the active pane (if enabled)
    if clipbeam_config.copy_file_path then
      pane:send_text(clipbeam_config.remote_path)
    end

    -- Step 4: Notify on success (if enabled)
    if clipbeam_config.notify_on_success then
      window:toast_notification("clipbeam", "Image uploaded to " .. clipbeam_config.remote_path, nil, 2000)
    end
  end)

  -- Return the keybinding for manual insertion
  return {
    key = "I",
    mods = "CTRL|SHIFT",
    action = wezterm.action.EmitEvent("clipbeam"),
  }
end

return M
