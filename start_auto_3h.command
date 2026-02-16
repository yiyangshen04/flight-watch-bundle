#!/bin/zsh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
./scripts/install_launchd.sh
printf "\n3-hour auto refresh is active. Press Enter to close..."
read -r
