#!/bin/zsh
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$BUNDLE_DIR/logs"
PID_FILE="$BUNDLE_DIR/.localhostrun.pid"
URL_FILE="$BUNDLE_DIR/localhostrun_url.txt"
LOG_FILE="$LOG_DIR/localhostrun.log"
PORT="${FLIGHT_WATCH_PORT:-8787}"

mkdir -p "$LOG_DIR"

"$BUNDLE_DIR/scripts/start_http_server.sh"

if [ -f "$PID_FILE" ]; then
  OLD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "${OLD_PID:-}" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    if [ -f "$URL_FILE" ]; then
      echo "localhost.run tunnel already running: $(cat "$URL_FILE")"
    else
      echo "localhost.run tunnel already running. URL pending in $LOG_FILE"
    fi
    exit 0
  fi
fi

nohup ssh \
  -o ExitOnForwardFailure=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -R 80:127.0.0.1:$PORT \
  nokey@localhost.run > "$LOG_FILE" 2>&1 &

PID=$!
echo "$PID" > "$PID_FILE"

URL=""
for _ in {1..90}; do
  if ! kill -0 "$PID" 2>/dev/null; then
    break
  fi

  # Only parse the actual tunnel line to avoid matching docs links like admin.localhost.run.
  TUNNEL_LINE="$(grep 'tunneled with tls termination' "$LOG_FILE" | tail -n 1 || true)"
  if [ -n "$TUNNEL_LINE" ]; then
    URL="$(printf '%s\n' "$TUNNEL_LINE" | sed -E 's/.*(https:\/\/[^ ]+).*/\1/' || true)"
  else
    URL=""
  fi

  if [ -n "$URL" ] && [ "$URL" != "https://localhost.run" ] && [ "$URL" != "https://admin.localhost.run" ]; then
    break
  fi

  sleep 1
done

if [ -n "$URL" ]; then
  READY=0
  for _ in {1..30}; do
    if curl -sS -o /dev/null --max-time 8 "$URL/flight_watch_overlay_chart.html" >/dev/null 2>&1; then
      READY=1
      break
    fi
    sleep 2
  done

  printf '%s' "$URL" > "$URL_FILE"
  echo "localhost.run URL: $URL"
  if [ "$READY" = "1" ]; then
    echo "Public URL is reachable now."
  else
    echo "URL created, but edge propagation may still be in progress (wait 1-2 minutes)."
  fi
  exit 0
fi

echo "Failed to capture localhost.run URL. Check $LOG_FILE"
exit 1
