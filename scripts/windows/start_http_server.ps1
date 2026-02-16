$ErrorActionPreference = 'Stop'

$BundleDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$RuntimeDir = if ($env:FLIGHT_WATCH_RUNTIME_DIR) { $env:FLIGHT_WATCH_RUNTIME_DIR } else { Join-Path $HOME '.flight_watch_bundle_runtime' }
$LogDir = Join-Path $BundleDir 'logs'
$PidFile = Join-Path $BundleDir '.http_server.pid'
$Port = if ($env:FLIGHT_WATCH_PORT) { $env:FLIGHT_WATCH_PORT } else { '8787' }
$OutLog = Join-Path $LogDir 'http_server.log'
$ErrLog = Join-Path $LogDir 'http_server.err.log'

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$ServeDir = $BundleDir
if ((Test-Path $RuntimeDir) -and (Test-Path (Join-Path $RuntimeDir 'flight_watch_overlay_chart.html'))) {
  $ServeDir = $RuntimeDir
}

if (Test-Path $PidFile) {
  $oldPid = (Get-Content $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
  if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
    Write-Host "HTTP server already running on http://127.0.0.1:$Port"
    exit 0
  }
}

$pythonExe = $null
$pythonArgs = @()

$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
  $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
}

if ($pythonCmd) {
  $pythonExe = $pythonCmd.Source
  $pythonArgs = @('-m', 'http.server', $Port, '--bind', '127.0.0.1', '--directory', $ServeDir)
} else {
  $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
  if ($pyLauncher) {
    $pythonExe = $pyLauncher.Source
    $pythonArgs = @('-3', '-m', 'http.server', $Port, '--bind', '127.0.0.1', '--directory', $ServeDir)
  }
}

if (-not $pythonExe) {
  throw 'Python was not found. Install Python 3 first.'
}

$proc = Start-Process -FilePath $pythonExe -ArgumentList $pythonArgs -RedirectStandardOutput $OutLog -RedirectStandardError $ErrLog -PassThru -WindowStyle Hidden
Set-Content -Path $PidFile -Value $proc.Id -Encoding ascii
Start-Sleep -Seconds 1

if (-not (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) {
  throw "Failed to start HTTP server. Check $OutLog and $ErrLog"
}

Write-Host "HTTP server started: http://127.0.0.1:$Port (serving $ServeDir)"
