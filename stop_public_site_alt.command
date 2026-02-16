#!/bin/zsh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
./scripts/stop_localhostrun_tunnel.sh
./scripts/stop_http_server.sh
printf "\nPublic site (alt) stopped. Press Enter to close..."
read -r
