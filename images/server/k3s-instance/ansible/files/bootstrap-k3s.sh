#!/usr/bin/env bash

set -eEuo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: ${0} PUBLIC_HOSTNAME" >&2
    exit 1
fi
K3S_HOSTNAME="${1}"

export INSTALL_K3S_SKIP_DOWNLOAD=true

echo "Using hostname ${K3S_HOSTNAME} as SAN" >&2

curl -sfL https://get.k3s.io | sh -s - server --tls-san 127.0.0.1 --tls-san "${K3S_HOSTNAME}" "${@}"
