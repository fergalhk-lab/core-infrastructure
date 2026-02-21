#!/usr/bin/env bash

set -eEuo pipefail

export INSTALL_K3S_SKIP_DOWNLOAD=true
HOSTNAME_FILE=/etc/k3s-hostname

if ! [ -f "${HOSTNAME_FILE}" ]; then
    echo "ERROR: File ${HOSTNAME_FILE} not found!" >&2
    exit 1
fi

K3S_HOSTNAME="$(cat "${HOSTNAME_FILE}")"

echo "Using hostname ${K3S_HOSTNAME} as SAN" >&2

curl -sfL https://get.k3s.io | sh -s - server --https-listen-port 443 --tls-san "${K3S_HOSTNAME}" "${@}"
