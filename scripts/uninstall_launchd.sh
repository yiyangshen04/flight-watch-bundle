#!/bin/zsh
set -euo pipefail

for LABEL in "com.hanson.flightwatch.1h" "com.hanson.flightwatch.2h" "com.hanson.flightwatch.3h"; do
  PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
  launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
  rm -f "$PLIST"
done

echo "Removed watcher plist(s)."
