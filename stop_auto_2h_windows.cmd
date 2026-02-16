@echo off
setlocal
set "REMOVED=0"

schtasks /Delete /TN "FlightWatch1h" /F >nul 2>nul && set "REMOVED=1"
schtasks /Delete /TN "FlightWatch2h" /F >nul 2>nul && set "REMOVED=1"
schtasks /Delete /TN "FlightWatch3h" /F >nul 2>nul && set "REMOVED=1"

if "%REMOVED%"=="1" (
  echo Removed watcher task(s).
) else (
  echo No FlightWatch task found.
)

echo Press any key to close...
pause >nul
