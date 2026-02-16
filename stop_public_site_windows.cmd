@echo off
setlocal
set "DIR=%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%scripts\windows\stop_cloudflare_tunnel.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%scripts\windows\stop_http_server.ps1"

echo.
echo Public site stopped. Press any key to close...
pause >nul
