#!/usr/bin/env bash

set -eEuo pipefail

export INSTALL_K3S_SKIP_DOWNLOAD=true

curl -sfL https://get.k3s.io | sh - "${@}"
