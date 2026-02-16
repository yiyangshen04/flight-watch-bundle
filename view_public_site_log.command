#!/bin/zsh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

CLOUDFLARE_LOG="$DIR/logs/cloudflared.log"
HTTP_LOG="$DIR/logs/http_server.log"

mkdir -p "$DIR/logs"
touch "$CLOUDFLARE_LOG" "$HTTP_LOG"

echo "Watching:"
echo "  $CLOUDFLARE_LOG"
echo "  $HTTP_LOG"
echo "(Press Ctrl+C to stop)"

tail -n 120 -f "$CLOUDFLARE_LOG" "$HTTP_LOG"
