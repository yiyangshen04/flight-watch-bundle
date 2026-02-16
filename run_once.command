#!/bin/zsh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
./scripts/run_cycle.sh
./scripts/open_dashboard.sh
printf "\nDone. Press Enter to close..."
read -r
