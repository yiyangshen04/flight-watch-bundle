#!/bin/zsh
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$BUNDLE_DIR/logs"
PID_FILE="$BUNDLE_DIR/.cloudflared.pid"
URL_FILE="$BUNDLE_DIR/cloudflare_url.txt"
LOG_FILE="$LOG_DIR/cloudflared.log"
PORT="${FLIGHT_WATCH_PORT:-8787}"

mkdir -p "$LOG_DIR"

"$BUNDLE_DIR/scripts/start_http_server.sh"

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared not found, installing via Homebrew..."
  brew install cloudflared
fi

if [ -f "$PID_FILE" ]; then
  OLD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "${OLD_PID:-}" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    if [ -f "$URL_FILE" ]; then
      echo "Cloudflare tunnel already running: $(cat "$URL_FILE")"
    else
      echo "Cloudflare tunnel already running. URL pending in $LOG_FILE"
    fi
    exit 0
  fi
fi

nohup cloudflared tunnel --url "http://127.0.0.1:$PORT" > "$LOG_FILE" 2>&1 &
PID=$!
echo "$PID" > "$PID_FILE"

URL=""
for _ in {1..90}; do
  if ! kill -0 "$PID" 2>/dev/null; then
    break
  fi
  URL="$(rg -o 'https://[-a-z0-9]+\.trycloudflare\.com' "$LOG_FILE" | tail -n 1 || true)"
  if [ -n "$URL" ]; then
    break
  fi
  sleep 1
done

if [ -n "$URL" ]; then
  # Quick tunnel DNS can take time to propagate; wait briefly before returning URL.
  READY=0
  for _ in {1..45}; do
    if curl -sS -o /dev/null --max-time 8 "$URL/flight_watch_overlay_chart.html" >/dev/null 2>&1; then
      READY=1
      break
    fi
    sleep 2
  done

  printf '%s' "$URL" > "$URL_FILE"
  echo "Cloudflare temporary URL: $URL"
  if [ "$READY" = "1" ]; then
    echo "Public URL is reachable now."
  else
    echo "URL created, but DNS/edge propagation may still be in progress (wait 1-3 minutes)."
  fi
  exit 0
fi

echo "Failed to capture Cloudflare URL. Check $LOG_FILE"
exit 1
