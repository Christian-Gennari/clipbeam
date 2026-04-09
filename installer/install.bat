@echo off
:: Clipbeam Installer Launcher
:: This batch file launches the PowerShell installer with proper permissions

title Clipbeam Installer for WezTerm

:: Check if running as administrator (not required, but helpful info)
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [INFO] Running as Administrator (not required, but OK)
) else (
    echo [INFO] Running as regular user (sufficient for installation)
)
echo.

:: Check if PowerShell is available
where powershell >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] PowerShell not found. This installer requires PowerShell.
    pause
    exit /b 1
)

:: Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"

:: Check if install.ps1 exists
if not exist "%SCRIPT_DIR%install.ps1" (
    echo [ERROR] install.ps1 not found in: %SCRIPT_DIR%
    echo Make sure both install.bat and install.ps1 are in the same folder.
    pause
    exit /b 1
)

if not exist "%SCRIPT_DIR%..\clipbeam.lua" (
    echo [ERROR] clipbeam.lua not found in: %SCRIPT_DIR%..
    echo Make sure clipbeam.lua is in the project root folder.
    pause
    exit /b 1
)

:: Launch PowerShell with execution policy bypass
:: This is needed because the script isn't signed
echo Launching installer...
echo.
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install.ps1" %*

:: Pause if there was an error
if %errorLevel% neq 0 (
    echo.
    echo Installation failed with error code %errorLevel%
    pause
)
