#!/bin/zsh
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$BUNDLE_DIR/.cloudflared.pid"
URL_FILE="$BUNDLE_DIR/cloudflare_url.txt"

if [ -f "$PID_FILE" ]; then
  PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "${PID:-}" ] && kill -0 "$PID" 2>/dev/null; then
    kill "$PID" || true
    sleep 1
    if kill -0 "$PID" 2>/dev/null; then
      kill -9 "$PID" || true
    fi
    echo "Cloudflare tunnel stopped."
  else
    echo "Cloudflare tunnel process was not running."
  fi
  rm -f "$PID_FILE"
else
  echo "Cloudflare tunnel is not running."
fi

rm -f "$URL_FILE"
