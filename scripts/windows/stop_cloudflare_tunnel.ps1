$ErrorActionPreference = 'Stop'

$BundleDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$PidFile = Join-Path $BundleDir '.cloudflared.pid'
$UrlFile = Join-Path $BundleDir 'cloudflare_url.txt'

if (Test-Path $PidFile) {
  $pidText = (Get-Content $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
  if ($pidText) {
    $proc = Get-Process -Id $pidText -ErrorAction SilentlyContinue
    if ($proc) {
      Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
      Write-Host 'Cloudflare tunnel stopped.'
    } else {
      Write-Host 'Cloudflare tunnel process was not running.'
    }
  }
  Remove-Item -Path $PidFile -Force -ErrorAction SilentlyContinue
} else {
  Write-Host 'Cloudflare tunnel is not running.'
}

Remove-Item -Path $UrlFile -Force -ErrorAction SilentlyContinue
