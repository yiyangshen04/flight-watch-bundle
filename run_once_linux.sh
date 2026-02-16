#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/scripts/linux/run_cycle.sh"
echo "Done. Open: $DIR/flight_watch_overlay_chart.html"
