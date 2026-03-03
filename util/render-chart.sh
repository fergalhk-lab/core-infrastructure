#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <config.yaml>" >&2
  exit 1
fi

CONFIG="$1"

if [[ ! -f "$CONFIG" ]]; then
  echo "Error: config file not found: $CONFIG" >&2
  exit 1
fi

RELEASE="$(yq -r '.name' "$CONFIG")"
NAMESPACE="$(yq -r '.namespace' "$CONFIG")"
CHART_SOURCE="$(yq -r '.chart.source' "$CONFIG")"
CHART_VERSION="$(yq -r '.chart.version' "$CONFIG")"
CHART_NAME="$(yq -r '.chart.name // .name' "$CONFIG")"

FILENAME="$(basename "$CONFIG" .yaml)"
if [[ "$FILENAME" != "$RELEASE" ]]; then
  echo "Error: filename '$FILENAME' does not match name '$RELEASE'" >&2
  exit 1
fi

# Write values to a temp file; handle configs with no values section
TMPFILE="$(mktemp)"
trap 'rm -f "$TMPFILE"' EXIT

VALUES="$(yq '.values // {}' "$CONFIG")"
printf '%s\n' "$VALUES" > "$TMPFILE"

echo ">>> Rendering $CHART_NAME version $CHART_VERSION as release '$RELEASE' in namespace '$NAMESPACE'" >&2
helm template "$RELEASE" "$CHART_NAME" \
  --repo "$CHART_SOURCE" \
  --namespace "$NAMESPACE" \
  --version "$CHART_VERSION" \
  --values "$TMPFILE"
