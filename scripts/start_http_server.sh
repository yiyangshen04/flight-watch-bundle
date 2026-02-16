#!/bin/zsh
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNTIME_DIR="${FLIGHT_WATCH_RUNTIME_DIR:-$HOME/.flight_watch_bundle_runtime}"
LOG_DIR="$BUNDLE_DIR/logs"
PID_FILE="$BUNDLE_DIR/.http_server.pid"
PORT="${FLIGHT_WATCH_PORT:-8787}"
LOG_FILE="$LOG_DIR/http_server.log"

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

mkdir -p "$LOG_DIR"

SERVE_DIR="$BUNDLE_DIR"
if [ -d "$RUNTIME_DIR" ] && [ -f "$RUNTIME_DIR/flight_watch_overlay_chart.html" ]; then
  SERVE_DIR="$RUNTIME_DIR"
fi

if [ -f "$PID_FILE" ]; then
  PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "${PID:-}" ] && kill -0 "$PID" 2>/dev/null; then
    echo "HTTP server already running on http://127.0.0.1:$PORT"
    exit 0
  fi
fi

PYTHON_BIN="$(command -v python3 || command -v python || true)"
if [ -z "$PYTHON_BIN" ]; then
  echo "Python is not available. Please install Python 3 first."
  exit 1
fi

nohup "$PYTHON_BIN" -m http.server "$PORT" --bind 127.0.0.1 --directory "$SERVE_DIR" > "$LOG_FILE" 2>&1 &
PID=$!
echo "$PID" > "$PID_FILE"
sleep 1

if kill -0 "$PID" 2>/dev/null; then
  echo "HTTP server started: http://127.0.0.1:$PORT (serving $SERVE_DIR)"
else
  echo "Failed to start HTTP server; check $LOG_FILE"
  exit 1
fi
