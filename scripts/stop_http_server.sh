#!/bin/zsh
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$BUNDLE_DIR/.http_server.pid"

if [ ! -f "$PID_FILE" ]; then
  echo "HTTP server is not running."
  exit 0
fi

PID="$(cat "$PID_FILE" 2>/dev/null || true)"
if [ -n "${PID:-}" ] && kill -0 "$PID" 2>/dev/null; then
  kill "$PID" || true
  sleep 1
  if kill -0 "$PID" 2>/dev/null; then
    kill -9 "$PID" || true
  fi
fi
rm -f "$PID_FILE"
echo "HTTP server stopped."
