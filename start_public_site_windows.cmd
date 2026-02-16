@echo off
setlocal
set "DIR=%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%scripts\windows\start_cloudflare_tunnel.ps1"
if errorlevel 1 (
  echo.
  echo start_cloudflare_tunnel failed. Check logs\cloudflared.log
  pause
  exit /b 1
)

set "URL="
for /f "usebackq delims=" %%i in ("%DIR%cloudflare_url.txt") do set "URL=%%i"
if defined URL (
  echo Public URL: %URL%/flight_watch_overlay_chart.html
  start "" "%URL%/flight_watch_overlay_chart.html"
)

echo.
echo Public site started. Press any key to close...
pause >nul
