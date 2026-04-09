# Clipbeam Installer for WezTerm
# Self-contained installer that auto-configures clipbeam plugin
# Usage: Run install.bat or directly: powershell -ExecutionPolicy Bypass -File install.ps1

param(
    [string]$SshHost,
    [string]$RemotePath = "~/.clipbeam/paste.png",
    [int]$MaxDimension = 3840,
    [switch]$Silent
)

# Configuration
$PluginName = "clipbeam"
$PluginDir = "$env:USERPROFILE\.config\wezterm\plugins\$PluginName"
$Keybinding = "CTRL+SHIFT+I"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Header {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   Clipbeam Installer for WezTerm" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Status($message, $type = "info") {
    $prefix = switch ($type) {
        "success" { "[OK] "; $color = "Green" }
        "error" { "[ERR] "; $color = "Red" }
        "warning" { "[WARN] "; $color = "Yellow" }
        default { "[*] "; $color = "White" }
    }
    Write-Host "$prefix$message" -ForegroundColor $color
}

function Test-WezTermInstalled {
    $weztermPaths = @(
        "$env:LOCALAPPDATA\Programs\WezTerm\wezterm.exe",
        "$env:ProgramFiles\WezTerm\wezterm.exe",
        "$env:ProgramFiles(x86)\WezTerm\wezterm.exe",
        "C:\tools\WezTerm\wezterm.exe"
    )
    
    foreach ($path in $weztermPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    # Check if in PATH using where.exe (more reliable than Get-Command)
    $whereResult = (& where.exe wezterm 2>$null)
    if ($whereResult) {
        return $whereResult
    }
    
    # Fallback to Get-Command
    try {
        $cmd = Get-Command "wezterm" -ErrorAction Stop
        return $cmd.Source
    } catch {
        return $null
    }
}

function Test-SSHAvailable {
    try {
        $null = Get-Command "ssh" -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Find-WezTermConfig {
    $configPaths = @(
        "$env:USERPROFILE\.wezterm.lua",
        "$env:USERPROFILE\.config\wezterm\wezterm.lua"
    )
    
    foreach ($path in $configPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    # Return default location (will create new)
    return "$env:USERPROFILE\.wezterm.lua"
}

function Backup-WezTermConfig($configPath) {
    if (Test-Path $configPath) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = "$configPath.backup.$timestamp"
        Copy-Item $configPath $backupPath -Force
        return $backupPath
    }
    return $null
}

function Test-ClipbeamInstalled($configPath) {
    if (-not (Test-Path $configPath)) {
        return $false
    }
    
    $content = Get-Content $configPath -Raw -ErrorAction SilentlyContinue
    if ($content -match "require.*$PluginName") {
        return $true
    }
    return $false
}

function Install-PluginFiles {
    # Create plugin directory
    if (-not (Test-Path $PluginDir)) {
        New-Item -ItemType Directory -Path $PluginDir -Force | Out-Null
    }
    
    # Copy clipbeam.lua to plugin directory (look in parent folder)
    $sourcePath = "$PSScriptRoot\..\clipbeam.lua"
    if (-not (Test-Path $sourcePath)) {
        Write-Status "clipbeam.lua not found in project root" "error"
        exit 1
    }
    
    Copy-Item $sourcePath "$PluginDir\$PluginName.lua" -Force
    Write-Status "Installed clipbeam.lua to $PluginDir" "success"
}

function Add-ClipbeamToConfig($configPath, $sshHost, $remotePath, $maxDim) {
    $clipbeamConfig = @"

-------------------------------------------------------------
--- CLIPBEAM (Image upload to remote server - AUTO-INSTALLED)
-------------------------------------------------------------
local clipbeam = require 'plugins.$PluginName'
local clipbeam_keybinding = clipbeam.setup({
  host = "$sshHost",
  remote_path = "$remotePath",
  max_dimension = $maxDim,
  copy_file_path = true,
  notify_on_success = false,
})
if clipbeam_keybinding then
  if not config.keys then config.keys = {} end
  table.insert(config.keys, clipbeam_keybinding)
end

"@

    if (Test-Path $configPath) {
        # Existing config - inject before return statement
        $content = Get-Content $configPath -Raw
        
        # Check if already installed
        if ($content -match "require.*plugins\.$PluginName") {
            Write-Status "Clipbeam is already configured in wezterm.lua" "warning"
            return $false
        }
        
        # Find "return config" and insert before it
        if ($content -match "(return config\s*)$") {
            $modified = $content -replace "(return config\s*)$", "$clipbeamConfig`$1"
        } else {
            # Append to end if no return statement found
            $modified = $content + $clipbeamConfig + "return config`n"
        }
        
        Set-Content $configPath $modified -NoNewline
    } else {
        # Create new config
        $newConfig = @"
local wezterm = require 'wezterm'
local config = wezterm.config_builder()
$clipbeamConfig
return config
"@
        Set-Content $configPath $newConfig
    }
    
    return $true
}

function Get-UserInput {
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Yellow
    Write-Host "---------------" -ForegroundColor Yellow
    
    # Get SSH host
    Write-Host "Enter your SSH destination for image uploads." -ForegroundColor White
    Write-Host "Format: user@hostname or user@IP" -ForegroundColor Gray
    Write-Host "Example: dev@omenhub" -ForegroundColor Gray
    
    do {
        $sshHost = Read-Host ">"
        if ([string]::IsNullOrWhiteSpace($sshHost)) {
            Write-Host "SSH host is required. Please try again." -ForegroundColor Red
        }
    } while ([string]::IsNullOrWhiteSpace($sshHost))
    
    Write-Host ""
    Write-Host "Remote save path: $RemotePath (default)" -ForegroundColor Gray
    Write-Host "Max dimension: $MaxDimension pixels (default)" -ForegroundColor Gray
    Write-Host "Keybinding: $Keybinding (default)" -ForegroundColor Gray
    Write-Host ""
    
    return $sshHost
}

# ============================================================================
# Main Installation Logic
# ============================================================================

Write-Header

# Check prerequisites
Write-Status "Checking prerequisites..."

$weztermPath = Test-WezTermInstalled
if ($weztermPath) {
    Write-Status "WezTerm found at $weztermPath" "success"
} else {
    Write-Status "WezTerm not found. Please install WezTerm first." "error"
    Write-Host "Download: https://wezfurlong.org/wezterm/installation.html" -ForegroundColor Cyan
    exit 1
}

if (Test-SSHAvailable) {
    Write-Status "SSH client found" "success"
} else {
    Write-Status "SSH client not found in PATH. Please install OpenSSH." "error"
    exit 1
}

# Get configuration
if ($Silent) {
    if (-not $SshHost) {
        Write-Status "Silent mode requires -SshHost parameter" "error"
        exit 1
    }
    $finalSshHost = $SshHost
} else {
    if ($SshHost) {
        $finalSshHost = $SshHost
        Write-Status "Using SSH host: $finalSshHost"
    } else {
        $finalSshHost = Get-UserInput
    }
}

# Find or create wezterm.lua
$configPath = Find-WezTermConfig
Write-Status "WezTerm config: $configPath"

# Backup existing config
$backupPath = Backup-WezTermConfig $configPath
if ($backupPath) {
    Write-Status "Created backup: $backupPath" "success"
}

# Check if already installed
if (Test-ClipbeamInstalled $configPath) {
    Write-Status "Clipbeam appears to be already installed"
    Write-Host ""
    $reinstall = Read-Host "Reinstall/Update? (y/N)"
    if ($reinstall -notmatch "^[Yy]$") {
        Write-Status "Installation cancelled" "warning"
        exit 0
    }
}

# Install plugin files
Write-Status "Installing plugin files..."
Install-PluginFiles

# Add to wezterm.lua
Write-Status "Configuring wezterm.lua..."
$result = Add-ClipbeamToConfig $configPath $finalSshHost $RemotePath $MaxDimension

if ($result) {
    Write-Status "Integrated with wezterm.lua" "success"
} else {
    Write-Status "Configuration skipped (already present)" "warning"
}

# ============================================================================
# Completion
# ============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Configuration Summary:" -ForegroundColor White
Write-Host "  SSH Host: $finalSshHost" -ForegroundColor Gray
Write-Host "  Remote Path: $RemotePath" -ForegroundColor Gray
Write-Host "  Keybinding: $Keybinding" -ForegroundColor Gray
Write-Host ""
Write-Host "Test it:" -ForegroundColor Yellow
Write-Host "  1. Take a screenshot (Win+Shift+S)" -ForegroundColor White
Write-Host "  2. Switch to WezTerm" -ForegroundColor White
Write-Host "  3. Press $Keybinding" -ForegroundColor White
Write-Host "  4. Image uploads to your server at $RemotePath" -ForegroundColor White
Write-Host ""
Write-Host "Run uninstall.bat to remove clipbeam." -ForegroundColor Gray
Write-Host ""

# Keep window open if double-clicked
if (-not $Silent) {
    Write-Host "Press any key to exit..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
