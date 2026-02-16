#!/bin/zsh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
./scripts/start_localhostrun_tunnel.sh
if [ -f "$DIR/localhostrun_url.txt" ]; then
  URL="$(tr -d '\r\n' < "$DIR/localhostrun_url.txt")"
  PAGE_URL="$URL/flight_watch_overlay_chart.html"
  echo "Public URL: $PAGE_URL"
  echo "$URL" | pbcopy
  echo "(Domain URL copied to clipboard)"
  open "$PAGE_URL"
fi
printf "\nPublic site (alt) started. Press Enter to close..."
read -r
