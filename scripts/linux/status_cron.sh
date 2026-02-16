#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$BUNDLE_DIR/logs"

echo "=== cron entries ==="
crontab -l 2>/dev/null | grep 'flight_watch_3h' || echo "(no flight_watch_3h cron job found)"

echo
echo "=== recent log ==="
if [ -f "$LOG_DIR/flight_watch_cycle.log" ]; then
  tail -n 40 "$LOG_DIR/flight_watch_cycle.log"
else
  echo "(no $LOG_DIR/flight_watch_cycle.log yet)"
fi
