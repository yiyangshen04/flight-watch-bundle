#!/bin/zsh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
./scripts/uninstall_launchd.sh
printf "\nAuto refresh stopped. Press Enter to close..."
read -r
