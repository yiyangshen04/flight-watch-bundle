#!/bin/zsh
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${FLIGHT_WATCH_PORT:-8787}"

"$BUNDLE_DIR/scripts/start_http_server.sh"
open "http://127.0.0.1:$PORT/flight_watch_overlay_chart.html"
