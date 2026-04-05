#!/usr/bin/env bash

set -euo pipefail

for cmd in go helm; do
  command -v "$cmd" &>/dev/null || { echo "Error: $cmd not found in PATH" >&2; exit 1; }
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <config.yaml>" >&2
  exit 1
fi

CONFIG="$1"

if [[ ! -f "$CONFIG" ]]; then
  echo "Error: config file not found: $CONFIG" >&2
  exit 1
fi

go run "${SCRIPT_DIR}/render-chart" -config "$CONFIG"
