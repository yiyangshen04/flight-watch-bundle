@echo off
setlocal
set "DIR=%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%scripts\windows\run_cycle.ps1"
if errorlevel 1 (
  echo.
  echo run_cycle failed. Check logs\flight_watch_cycle.log
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%scripts\windows\start_http_server.ps1" >nul
start "" "http://127.0.0.1:8787/flight_watch_overlay_chart.html"

echo.
echo Done. Press any key to close...
pause >nul
