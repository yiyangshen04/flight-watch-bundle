#!/bin/zsh
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_DIR="${FLIGHT_WATCH_RUNTIME_DIR:-$HOME/.flight_watch_bundle_runtime}"
LABEL="com.hanson.flightwatch.3h"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$HOME/Library/LaunchAgents" "$BUNDLE_DIR/logs" "$RUNTIME_DIR" "$RUNTIME_DIR/logs"

# launchd may not have Desktop permission in some macOS setups, so we run from a runtime mirror under $HOME.
rsync -a --delete \
  --exclude '.cycle.lock' \
  --exclude '.http_server.pid' \
  --exclude '.cloudflared.pid' \
  --exclude 'cloudflare_url.txt' \
  --exclude 'logs/' \
  "$BUNDLE_DIR/" "$RUNTIME_DIR/"

RUN_CMD="cd '$RUNTIME_DIR'; SYNC_BACK_DIR='$BUNDLE_DIR' ./scripts/run_cycle.sh"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-lc</string>
    <string>$RUN_CMD</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$RUNTIME_DIR</string>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>10800</integer>
  <key>StandardOutPath</key>
  <string>$RUNTIME_DIR/logs/launchd.out.log</string>
  <key>StandardErrorPath</key>
  <string>$RUNTIME_DIR/logs/launchd.err.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
for OLD_LABEL in "com.hanson.flightwatch.1h" "com.hanson.flightwatch.2h"; do
  OLD_PLIST="$HOME/Library/LaunchAgents/$OLD_LABEL.plist"
  launchctl bootout "gui/$(id -u)" "$OLD_PLIST" >/dev/null 2>&1 || true
  rm -f "$OLD_PLIST"
done
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo "Installed and started 3-hour watcher: $LABEL"
echo "Plist: $PLIST"
echo "Runtime dir: $RUNTIME_DIR"
