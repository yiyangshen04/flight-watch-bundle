#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$BUNDLE_DIR/scripts/linux/run_cycle.sh"
LOG_DIR="$BUNDLE_DIR/logs"
CRON_TAG="# flight_watch_3h"
CRON_EXPR="0 */3 * * * cd \"$BUNDLE_DIR\" && \"$RUNNER\" >> \"$LOG_DIR/cron.log\" 2>&1 $CRON_TAG"

mkdir -p "$LOG_DIR"

CURRENT_CRON="$(crontab -l 2>/dev/null || true)"
FILTERED_CRON="$(printf '%s\n' "$CURRENT_CRON" | sed '/# flight_watch_3h$/d')"

{
  printf '%s\n' "$FILTERED_CRON"
  printf '%s\n' "$CRON_EXPR"
} | sed '/^[[:space:]]*$/d' | crontab -

echo "Installed 3-hour cron job."
echo "Rule: $CRON_EXPR"
echo "Log: $LOG_DIR/cron.log"

"$RUNNER"
echo "Ran one cycle immediately."
