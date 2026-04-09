# Clipbeam

Beam clipboard screenshots from Windows to a remote server via SSH — directly from WezTerm.

## What is Clipbeam?

Clipbeam is a WezTerm plugin that lets you instantly upload screenshots to a remote server using a simple keyboard shortcut. No manual file saving, no SCP commands — just snap, beam, done.

**The workflow:**
1. Take a screenshot with `Win+Shift+S`
2. Press `Ctrl+Shift+I` in WezTerm
3. Image appears on your remote server at `/tmp/paste_img.png`

## Installation

### Quick Install (Recommended)

1. Download and extract the latest release
2. Double-click `installer/install.bat`
3. Enter your SSH destination when prompted (e.g., `dev@myserver`)
4. Done!

The installer will:
- Check that WezTerm and SSH are installed
- Install the clipbeam plugin
- Safely integrate with your existing WezTerm config (with backup)
- Configure everything automatically

### Silent Install (Advanced)

For automated/scripted installation:

```batch
installer\install.bat -SshHost "dev@myserver" -Silent
```

## Usage

After installation:

1. Take a screenshot with `Win+Shift+S` (snipping tool)
2. Switch to WezTerm
3. Press `Ctrl+Shift+I`
4. The image is uploaded and the remote path (`/tmp/paste_img.png`) is typed into your terminal

## Uninstallation

To completely remove Clipbeam:

1. Double-click `installer/uninstall.bat`
2. The uninstaller will:
   - Remove Clipbeam code from your WezTerm config
   - Delete plugin files
   - Offer to restore from backup

### Silent Uninstall

```batch
installer\uninstall.bat -Silent
```

## Features

- **One-click installation** — Auto-configures everything, no manual setup needed
- **Screenshot capture** — Works with Windows Snipping Tool (Win+Shift+S)
- **SSH transfer** — Base64-encoded transfer, no dependencies on remote server
- **Safe integration** — Backs up your existing WezTerm config before modifying
- **Easy uninstall** — Completely reversible

## How It Works

1. PowerShell captures the image from Windows clipboard as base64
2. SSH transfers the base64 data to your remote server
3. Remote server decodes it back to a PNG file using `base64 -d`
4. WezTerm types the file path into your active terminal pane

Zero dependencies on the remote server — just needs the standard `base64` utility (included on Ubuntu/Debian by default).

## Requirements

- Windows 10/11
- [WezTerm](https://wezfurlong.org/wezterm/) terminal emulator
- SSH client (usually included with Windows or Git for Windows)
- SSH access to a remote server (with key-based auth recommended)

## Configuration

The installer auto-configures sensible defaults:

- **Remote path:** `/tmp/paste_img.png`
- **Max dimension:** 3840 pixels (4K)
- **Keybinding:** `Ctrl+Shift+I`

### Changing Settings

To modify settings after installation, edit your `wezterm.lua`:

```lua
local clipbeam = require 'plugins.clipbeam'
local clipbeam_keybinding = clipbeam.setup({
  host = "dev@myserver",
  remote_path = "/custom/path/image.png",
  max_dimension = 1920,
  copy_file_path = true,
  notify_on_success = false,
})
if clipbeam_keybinding then
  table.insert(config.keys, clipbeam_keybinding)
end
```

## Project Structure

```
clipbeam/
├── clipbeam.lua          # The WezTerm plugin (source of truth)
├── installer/
│   ├── install.bat       # Double-click to install
│   ├── install.ps1       # Installation logic
│   ├── uninstall.bat     # Double-click to uninstall
│   └── uninstall.ps1     # Uninstallation logic
├── LICENSE
└── README.md             # This file
```

## Troubleshooting

### "WezTerm not found"

Make sure WezTerm is installed. Download from: https://wezfurlong.org/wezterm/installation.html

### "SSH transfer failed"

- Verify SSH access works: `ssh your-host` should connect without password prompt
- Set up SSH keys if needed: `ssh-copy-id user@hostname`

### "No image in clipboard"

Take a screenshot first with `Win+Shift+S` before pressing `Ctrl+Shift+I`

### Image not appearing on remote

Check the remote path exists and you have write permissions:
```bash
ls -la /tmp/
```

## Building from Source

If you want to modify or contribute:

1. Clone this repository
2. Edit `clipbeam.lua` for plugin changes
3. Edit files in `installer/` for installer changes
4. Test by running `installer/install.bat`

## Roadmap

- [x] Screenshot capture support
- [x] Self-contained installer
- [ ] Support for copied image files (from Explorer)
- [ ] Custom keybinding configuration in installer
- [ ] GUI installer option

## License

See [LICENSE](LICENSE) file for details.

## Credits

Built for developers who need seamless image sharing between Windows and remote Linux development servers.
