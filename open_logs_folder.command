#!/bin/zsh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME_DIR="${FLIGHT_WATCH_RUNTIME_DIR:-$HOME/.flight_watch_bundle_runtime}"

mkdir -p "$DIR/logs" "$RUNTIME_DIR/logs"

open "$DIR/logs"
open "$RUNTIME_DIR/logs"

echo "Opened log folders:"
echo "  $DIR/logs"
echo "  $RUNTIME_DIR/logs"

echo "Press Enter to close..."
read -r
