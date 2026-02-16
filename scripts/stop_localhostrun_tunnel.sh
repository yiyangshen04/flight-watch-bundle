#!/bin/zsh
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$BUNDLE_DIR/.localhostrun.pid"
URL_FILE="$BUNDLE_DIR/localhostrun_url.txt"

if [ -f "$PID_FILE" ]; then
  PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "${PID:-}" ] && kill -0 "$PID" 2>/dev/null; then
    kill "$PID" || true
    sleep 1
    if kill -0 "$PID" 2>/dev/null; then
      kill -9 "$PID" || true
    fi
    echo "localhost.run tunnel stopped."
  else
    echo "localhost.run tunnel process was not running."
  fi
  rm -f "$PID_FILE"
else
  echo "localhost.run tunnel is not running."
fi

rm -f "$URL_FILE"
