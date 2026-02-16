#!/bin/zsh
set -euo pipefail
RUNTIME_DIR="${FLIGHT_WATCH_RUNTIME_DIR:-$HOME/.flight_watch_bundle_runtime}"
OUT_LOG="$RUNTIME_DIR/logs/launchd.out.log"
ERR_LOG="$RUNTIME_DIR/logs/launchd.err.log"

mkdir -p "$RUNTIME_DIR/logs"
touch "$OUT_LOG" "$ERR_LOG"

echo "Watching:"
echo "  $OUT_LOG"
echo "  $ERR_LOG"
echo "(Press Ctrl+C to stop)"

tail -n 120 -f "$OUT_LOG" "$ERR_LOG"
