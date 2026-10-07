@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RestartTrafficMonitor.ps1" -UseRepositorySettings
if errorlevel 1 (
    echo.
    echo Applying preferred settings failed. See the message above.
    pause
    exit /b 1
)
exit /b 0
