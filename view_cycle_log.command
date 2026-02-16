#!/bin/zsh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME_DIR="${FLIGHT_WATCH_RUNTIME_DIR:-$HOME/.flight_watch_bundle_runtime}"

LOG_FILE="$RUNTIME_DIR/logs/flight_watch_cycle.log"
if [ ! -f "$LOG_FILE" ]; then
  LOG_FILE="$DIR/logs/flight_watch_cycle.log"
fi

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

echo "Watching: $LOG_FILE"
echo "(Press Ctrl+C to stop)"

tail -n 120 -f "$LOG_FILE"
