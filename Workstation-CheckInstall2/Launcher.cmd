@echo off
setlocal
set "ROOT=%~dp0"
REM %%~dp0 has a trailing backslash. Remove it before passing the path in a
REM quoted PowerShell argument, where that backslash can escape the quote.
set "ROOT=%ROOT:~0,-1%"
set "SCAN_LOG=%ROOT%\Logs\Initial-Scan.log"

REM Check if running as administrator
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Requesting administrator elevation...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b %errorlevel%
)

REM Create the initial status file before opening the dashboard. The HTA can
REM then always render a result instead of waiting forever for a detached scan.
if not exist "%ROOT%\Logs" mkdir "%ROOT%\Logs"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\Engine\Scan-All.ps1" -PackageRoot "%ROOT%" 1>"%SCAN_LOG%" 2>&1
if not "%errorlevel%"=="0" (
    echo.
    echo The workstation scan failed. The dashboard was not opened.
    echo.
    echo Error details from %SCAN_LOG%:
    type "%SCAN_LOG%"
    pause
    exit /b 1
)

REM Already elevated - launch the HTA. Any scans started from this dashboard
REM inherit its elevated token, so they do not need another UAC launch.
mshta.exe "%ROOT%\Workstation-Validator.hta"
