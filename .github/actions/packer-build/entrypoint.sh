#!/usr/bin/env bash
set -eExuo pipefail

DIRECTORY="$1"
SAVE_SNAPSHOT="${2:-false}"

cd "$GITHUB_WORKSPACE/${DIRECTORY}"

packer init .

packer build -var "save_snapshot=${SAVE_SNAPSHOT}" .
