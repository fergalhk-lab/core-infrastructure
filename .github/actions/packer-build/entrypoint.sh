#!/usr/bin/env bash
set -eEuo pipefail

DIRECTORY="$1"
SAVE_SNAPSHOT="${2:-false}"

cd "$GITHUB_WORKSPACE"
echo '+ Packer init' >&2
packer init "$DIRECTORY"
echo '+ Packer build' >&2
packer build -var "save_snapshot=${SAVE_SNAPSHOT}" "$DIRECTORY"
echo '+ Success!' >&2
