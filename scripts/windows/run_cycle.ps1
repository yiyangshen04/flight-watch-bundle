$ErrorActionPreference = 'Stop'

$BundleDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$LogDir = Join-Path $BundleDir 'logs'
$LockDir = Join-Path $BundleDir '.cycle.lock'
$LogFile = Join-Path $LogDir 'flight_watch_cycle.log'
$SyncBackDir = $env:SYNC_BACK_DIR

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

if (Test-Path $LockDir) {
  Add-Content -Path $LogFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Another cycle is already running, skip."
  exit 0
}

New-Item -ItemType Directory -Path $LockDir -Force | Out-Null

try {
  if (-not $env:TRACK_START_DATE) { $env:TRACK_START_DATE = '2026-02-15' }
  if (-not $env:WINDOW_DAYS) { $env:WINDOW_DAYS = '36' }
  if (-not $env:STAY_DAYS) { $env:STAY_DAYS = '16' }
  if (-not $env:QUERY_TIMEZONE) { $env:QUERY_TIMEZONE = 'America/Chicago' }
  if (-not $env:PER_DATE_MAX_ATTEMPTS) { $env:PER_DATE_MAX_ATTEMPTS = '6' }
  if (-not $env:MISSING_MAX_ATTEMPTS) { $env:MISSING_MAX_ATTEMPTS = '4' }
  if (-not $env:RETRY_BASE_DELAY_MS) { $env:RETRY_BASE_DELAY_MS = '1200' }
  if (-not $env:RETRY_MAX_DELAY_MS) { $env:RETRY_MAX_DELAY_MS = '30000' }
  if (-not $env:RETRY_JITTER_MS) { $env:RETRY_JITTER_MS = '650' }
  if (-not $env:RATE_LIMIT_COOLDOWN_MS) { $env:RATE_LIMIT_COOLDOWN_MS = '90000' }

  $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
  if (-not $nodeCmd) {
    throw 'node was not found in PATH. Install Node.js and retry.'
  }

  Add-Content -Path $LogFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] cycle start"

  & $nodeCmd.Source (Join-Path $BundleDir 'run_flight_watch_round_http.mjs') 2>&1 | Out-File -FilePath $LogFile -Append -Encoding utf8
  if ($LASTEXITCODE -ne 0) {
    throw "run_flight_watch_round_http.mjs failed with exit code $LASTEXITCODE"
  }

  Add-Content -Path $LogFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] cycle success"

  if ($SyncBackDir -and ($SyncBackDir -ne $BundleDir)) {
    New-Item -ItemType Directory -Force -Path $SyncBackDir | Out-Null
    foreach ($name in @('flight_watch_latest_round.json', 'flight_watch_latest_round.csv', 'flight_watch_price_history.json', 'flight_watch_overlay_chart.html')) {
      $src = Join-Path $BundleDir $name
      $dst = Join-Path $SyncBackDir $name
      if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Force -ErrorAction SilentlyContinue
      }
    }
  }
}
finally {
  Remove-Item -Path $LockDir -Recurse -Force -ErrorAction SilentlyContinue
}
