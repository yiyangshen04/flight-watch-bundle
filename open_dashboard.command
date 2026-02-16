#!/bin/zsh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
./scripts/open_dashboard.sh
printf "\nDashboard opened. Press Enter to close..."
read -r
