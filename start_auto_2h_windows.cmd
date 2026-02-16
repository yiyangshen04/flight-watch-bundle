@echo off
setlocal
set "DIR=%~dp0"
set "TASK_NAME=FlightWatch3h"
set "TASK_CMD=powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%DIR%scripts\windows\run_cycle.ps1\""

schtasks /Delete /TN "FlightWatch1h" /F >nul 2>nul
schtasks /Delete /TN "FlightWatch2h" /F >nul 2>nul
schtasks /Delete /TN "FlightWatch3h" /F >nul 2>nul
schtasks /Create /TN "%TASK_NAME%" /SC HOURLY /MO 3 /TR "%TASK_CMD%" /F >nul
if errorlevel 1 (
  echo Failed to create scheduled task.
  pause
  exit /b 1
)

schtasks /Run /TN "%TASK_NAME%" >nul 2>nul

echo Installed and started 3-hour watcher: %TASK_NAME%
echo Press any key to close...
pause >nul
