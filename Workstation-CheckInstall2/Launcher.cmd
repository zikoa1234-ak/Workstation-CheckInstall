@echo off
setlocal
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "WS_LAUNCH=%~f0"
net session >nul 2>&1
if not "%errorlevel%"=="0" (
 powershell.exe -NoProfile -Command "Start-Process -FilePath $env:WS_LAUNCH -Verb RunAs"
 exit /b
)
powershell.exe -NoProfile -STA -ExecutionPolicy RemoteSigned -File "%ROOT%\Workstation-Validator.ps1"
if errorlevel 1 pause
