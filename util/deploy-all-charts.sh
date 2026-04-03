#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <charts-dir>" >&2
  exit 1
fi

CHARTS_DIR="$1"

if [[ ! -d "$CHARTS_DIR" ]]; then
  echo "Error: directory not found: $CHARTS_DIR" >&2
  exit 1
fi

shopt -s nullglob
charts=("$CHARTS_DIR"/*.yaml)

if [[ ${#charts[@]} -eq 0 ]]; then
  echo "Error: no chart configs found in $CHARTS_DIR" >&2
  exit 1
fi

for chart in "${charts[@]}"; do
  echo "=== Deploying $(basename "$chart") ==="
  "$SCRIPT_DIR/deploy-chart.sh" "$chart"
done
