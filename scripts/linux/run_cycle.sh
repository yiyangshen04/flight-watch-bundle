#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$BUNDLE_DIR/logs"
LOCK_DIR="$BUNDLE_DIR/.cycle.lock"
LOG_FILE="$LOG_DIR/flight_watch_cycle.log"

mkdir -p "$LOG_DIR"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  printf '[%s] Another cycle is already running, skip.\n' "$(date '+%Y-%m-%d %H:%M:%S')" >>"$LOG_FILE"
  exit 0
fi

cleanup() {
  rmdir "$LOCK_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

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
  printf '[%s] cycle start\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  node "$BUNDLE_DIR/run_flight_watch_round_http.mjs"
  printf '[%s] cycle success\n' "$(date '+%Y-%m-%d %H:%M:%S')"
} >>"$LOG_FILE" 2>&1
