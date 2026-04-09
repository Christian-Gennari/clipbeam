@echo off
:: Clipbeam Uninstaller Launcher
:: This batch file launches the PowerShell uninstaller with proper permissions

title Clipbeam Uninstaller

:: Check if PowerShell is available
where powershell >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] PowerShell not found. This uninstaller requires PowerShell.
    pause
    exit /b 1
)

:: Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"

:: Check if uninstall.ps1 exists
if not exist "%SCRIPT_DIR%uninstall.ps1" (
    echo [ERROR] uninstall.ps1 not found in: %SCRIPT_DIR%
    pause
    exit /b 1
)

:: Launch PowerShell with execution policy bypass
echo Launching uninstaller...
echo.
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%uninstall.ps1" %*

:: Pause if there was an error
if %errorLevel% neq 0 (
    echo.
    echo Uninstallation failed with error code %errorLevel%
    pause
)
