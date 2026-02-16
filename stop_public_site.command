#!/bin/zsh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
./scripts/stop_cloudflare_tunnel.sh
./scripts/stop_http_server.sh
printf "\nPublic site stopped. Press Enter to close..."
read -r
