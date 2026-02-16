$ErrorActionPreference = 'Stop'

$BundleDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$LogDir = Join-Path $BundleDir 'logs'
$PidFile = Join-Path $BundleDir '.cloudflared.pid'
$UrlFile = Join-Path $BundleDir 'cloudflare_url.txt'
$LogFile = Join-Path $LogDir 'cloudflared.log'
$ErrLog = Join-Path $LogDir 'cloudflared.err.log'
$Port = if ($env:FLIGHT_WATCH_PORT) { $env:FLIGHT_WATCH_PORT } else { '8787' }

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

& (Join-Path $PSScriptRoot 'start_http_server.ps1')

$cloudflaredCmd = Get-Command cloudflared -ErrorAction SilentlyContinue
if (-not $cloudflaredCmd) {
  throw 'cloudflared was not found. Install with: winget install Cloudflare.cloudflared'
}

if (Test-Path $PidFile) {
  $oldPid = (Get-Content $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
  if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
    if (Test-Path $UrlFile) {
      Write-Host "Cloudflare tunnel already running: $(Get-Content $UrlFile -Raw)"
    } else {
      Write-Host "Cloudflare tunnel already running. URL pending in $LogFile"
    }
    exit 0
  }
}

$proc = Start-Process -FilePath $cloudflaredCmd.Source -ArgumentList @('tunnel', '--url', "http://127.0.0.1:$Port") -RedirectStandardOutput $LogFile -RedirectStandardError $ErrLog -PassThru -WindowStyle Hidden
Set-Content -Path $PidFile -Value $proc.Id -Encoding ascii

$url = ''
for ($i = 0; $i -lt 90; $i++) {
  if (-not (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) {
    break
  }

  if (Test-Path $LogFile) {
    $text = Get-Content $LogFile -Raw -ErrorAction SilentlyContinue
    $matches = [regex]::Matches($text, 'https://[-a-z0-9]+\.trycloudflare\.com')
    if ($matches.Count -gt 0) {
      $url = $matches[$matches.Count - 1].Value
      break
    }
  }

  Start-Sleep -Seconds 1
}

if (-not $url) {
  throw "Failed to capture Cloudflare URL. Check $LogFile"
}

$ready = $false
for ($i = 0; $i -lt 45; $i++) {
  try {
    $resp = Invoke-WebRequest -Uri "$url/flight_watch_overlay_chart.html" -Method Head -TimeoutSec 8 -UseBasicParsing
    if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 500) {
      $ready = $true
      break
    }
  } catch {
    # wait for propagation
  }
  Start-Sleep -Seconds 2
}

Set-Content -Path $UrlFile -Value $url -Encoding ascii -NoNewline
Write-Host "Cloudflare temporary URL: $url"
if ($ready) {
  Write-Host 'Public URL is reachable now.'
} else {
  Write-Host 'URL created, but DNS/edge propagation may still be in progress (wait 1-3 minutes).'
}
