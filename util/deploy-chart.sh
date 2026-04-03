#!/usr/bin/env bash

set -euo pipefail

for cmd in yq kubectl go; do
  command -v "$cmd" &>/dev/null || { echo "Error: $cmd not found in PATH" >&2; exit 1; }
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
render-chart() { go run "${SCRIPT_DIR}/render-chart" "$@"; }

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <config.yaml>" >&2
  exit 1
fi

CONFIG="$1"

if [[ ! -f "$CONFIG" ]]; then
  echo "Error: config file not found: $CONFIG" >&2
  exit 1
fi

NAMESPACE="$(yq -r '.namespace' "$CONFIG")"

if [[ -z "$NAMESPACE" || "$NAMESPACE" == "null" ]]; then
  echo "Error: 'namespace' field missing or null in $CONFIG" >&2
  exit 1
fi

echo ">>> Ensuring namespace '$NAMESPACE' exists"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ">>> Deploying chart from $CONFIG to namespace '$NAMESPACE'"
MANIFESTS="$(render-chart -config "$CONFIG")"
if [[ -z "$MANIFESTS" ]]; then
  echo "Error: render-chart produced no output for $CONFIG" >&2
  exit 1
fi

kubectl apply -f - --server-side <<< "$MANIFESTS"
