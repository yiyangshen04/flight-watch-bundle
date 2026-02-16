$ErrorActionPreference = 'Stop'

$BundleDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$PidFile = Join-Path $BundleDir '.http_server.pid'

if (-not (Test-Path $PidFile)) {
  Write-Host 'HTTP server is not running.'
  exit 0
}

$pidText = (Get-Content $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
if ($pidText) {
  $proc = Get-Process -Id $pidText -ErrorAction SilentlyContinue
  if ($proc) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  }
}

Remove-Item -Path $PidFile -Force -ErrorAction SilentlyContinue
Write-Host 'HTTP server stopped.'
