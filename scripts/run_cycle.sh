#!/bin/zsh
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$BUNDLE_DIR/logs"
LOCK_DIR="$BUNDLE_DIR/.cycle.lock"
LOG_FILE="$LOG_DIR/flight_watch_cycle.log"
SYNC_BACK_DIR="${SYNC_BACK_DIR:-}"

mkdir -p "$LOG_DIR"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Another cycle is already running, skip." >> "$LOG_FILE"
  exit 0
fi
trap 'rmdir "$LOCK_DIR" >/dev/null 2>&1 || true' EXIT

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export TRACK_START_DATE="${TRACK_START_DATE:-2026-02-15}"
export WINDOW_DAYS="${WINDOW_DAYS:-36}"
export STAY_DAYS="${STAY_DAYS:-16}"
export QUERY_TIMEZONE="${QUERY_TIMEZONE:-America/Chicago}"
export PER_DATE_MAX_ATTEMPTS="${PER_DATE_MAX_ATTEMPTS:-6}"
export MISSING_MAX_ATTEMPTS="${MISSING_MAX_ATTEMPTS:-4}"
export RETRY_BASE_DELAY_MS="${RETRY_BASE_DELAY_MS:-1200}"
export RETRY_MAX_DELAY_MS="${RETRY_MAX_DELAY_MS:-30000}"
export RETRY_JITTER_MS="${RETRY_JITTER_MS:-650}"
export RATE_LIMIT_COOLDOWN_MS="${RATE_LIMIT_COOLDOWN_MS:-90000}"

{
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] cycle start"
  /usr/bin/env node "$BUNDLE_DIR/run_flight_watch_round_http.mjs"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] cycle success"
} >> "$LOG_FILE" 2>&1

if [ -n "$SYNC_BACK_DIR" ] && [ "$SYNC_BACK_DIR" != "$BUNDLE_DIR" ]; then
  mkdir -p "$SYNC_BACK_DIR"
  for f in \
    flight_watch_latest_round.json \
    flight_watch_latest_round.csv \
    flight_watch_price_history.json \
    flight_watch_overlay_chart.html; do
    if [ -f "$BUNDLE_DIR/$f" ]; then
      cp "$BUNDLE_DIR/$f" "$SYNC_BACK_DIR/$f" 2>/dev/null || true
    fi
  done
fi
