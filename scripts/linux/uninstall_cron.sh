#!/usr/bin/env bash
set -euo pipefail

CURRENT_CRON="$(crontab -l 2>/dev/null || true)"
FILTERED_CRON="$(printf '%s\n' "$CURRENT_CRON" | sed '/# flight_watch_3h$/d')"

if [ -n "$FILTERED_CRON" ]; then
  printf '%s\n' "$FILTERED_CRON" | crontab -
else
  crontab -r 2>/dev/null || true
fi

echo "Removed flight_watch_3h cron job."
