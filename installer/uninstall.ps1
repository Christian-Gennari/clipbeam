# Clipbeam Uninstaller for WezTerm
# Safely removes clipbeam plugin and restores configuration
# Usage: Run uninstall.bat or directly: powershell -ExecutionPolicy Bypass -File uninstall.ps1

param(
    [switch]$KeepBackup,
    [switch]$Silent
)

# Configuration
$PluginName = "clipbeam"
$PluginDir = "$env:USERPROFILE\.config\wezterm\plugins\$PluginName"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Header {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   Clipbeam Uninstaller" -ForegroundColor Cyan
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
    
    return $null
}

function Find-BackupFiles {
    $configPath = Find-WezTermConfig
    if (-not $configPath) {
        return @()
    }
    
    $backupPattern = "$configPath.backup.*"
    $backups = Get-ChildItem $backupPattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    return $backups
}

function Test-ClipbeamInstalled {
    $configPath = Find-WezTermConfig
    if (-not $configPath) {
        return $false
    }
    
    $content = Get-Content $configPath -Raw -ErrorAction SilentlyContinue
    if ($content -match "require.*plugins\.$PluginName") {
        return $true
    }
    return $false
}

function Remove-ClipbeamFromConfig($configPath) {
    if (-not (Test-Path $configPath)) {
        return $false
    }
    
    $content = Get-Content $configPath -Raw
    
    # Remove the clipbeam section (from CLIPBEAM comment to end of clipbeam block)
    # Pattern matches the AUTO-INSTALLED block we added
    $pattern = "\r?\n?\s*---\s*CLIPBEAM.*?(?=\r?\nreturn config|$)"
    $modified = $content -replace $pattern, ""
    
    # Clean up any double newlines left behind
    $modified = $modified -replace "\r?\n\r?\n\r?\n", "`r`n`r`n"
    
    Set-Content $configPath $modified -NoNewline
    return $true
}

function Remove-PluginFiles {
    if (Test-Path $PluginDir) {
        Remove-Item $PluginDir -Recurse -Force
        return $true
    }
    return $false
}

# ============================================================================
# Main Uninstallation Logic
# ============================================================================

Write-Header

# Check if clipbeam is installed
if (-not (Test-ClipbeamInstalled)) {
    Write-Status "Clipbeam does not appear to be installed" "warning"
    
    # Still offer to clean up files if they exist
    if (Test-Path $PluginDir) {
        Write-Host ""
        $cleanup = Read-Host "Found plugin files. Remove them? (y/N)"
        if ($cleanup -match "^[Yy]$") {
            Remove-PluginFiles
            Write-Status "Plugin files removed" "success"
        }
    }
    
    Write-Host ""
    if (-not $Silent) {
        Write-Host "Press any key to exit..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    exit 0
}

Write-Status "Found clipbeam installation"

# Show backup options
$backups = Find-BackupFiles
if ($backups.Count -gt 0) {
    Write-Host ""
    Write-Host "Available backups:" -ForegroundColor Yellow
    $i = 1
    foreach ($backup in $backups | Select-Object -First 5) {
        $date = $backup.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        Write-Host "  $i. $($backup.Name) ($date)" -ForegroundColor Gray
        $i++
    }
}

# Confirm uninstallation
if (-not $Silent) {
    Write-Host ""
    $confirm = Read-Host "Uninstall clipbeam? (y/N)"
    if ($confirm -notmatch "^[Yy]$") {
        Write-Status "Uninstallation cancelled" "warning"
        exit 0
    }
}

# Perform uninstallation
Write-Host ""
Write-Status "Removing clipbeam from wezterm.lua..."
$configPath = Find-WezTermConfig
if ($configPath) {
    Remove-ClipbeamFromConfig $configPath
    Write-Status "Removed from wezterm.lua" "success"
} else {
    Write-Status "Could not find wezterm.lua" "warning"
}

Write-Status "Removing plugin files..."
if (Remove-PluginFiles) {
    Write-Status "Plugin files removed" "success"
} else {
    Write-Status "No plugin files found" "warning"
}

# Handle backup restoration
if ($backups.Count -gt 0 -and -not $KeepBackup) {
    Write-Host ""
    $latestBackup = $backups[0]
    Write-Host "Latest backup found: $($latestBackup.Name)" -ForegroundColor Yellow
    
    if (-not $Silent) {
        $restore = Read-Host "Restore from this backup? (y/N)"
        if ($restore -match "^[Yy]$") {
            Copy-Item $latestBackup.FullName $configPath -Force
            Write-Status "Restored from backup" "success"
            
            $deleteBackup = Read-Host "Delete backup file? (y/N)"
            if ($deleteBackup -match "^[Yy]$") {
                Remove-Item $latestBackup.FullName
                Write-Status "Backup deleted" "success"
            }
        }
    }
}

# ============================================================================
# Completion
# ============================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   Uninstallation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Clipbeam has been removed from your system." -ForegroundColor White
Write-Host ""
Write-Host "To reinstall, run install.bat again." -ForegroundColor Gray
Write-Host ""

if (-not $Silent) {
    Write-Host "Press any key to exit..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
