#!/usr/bin/env bash

set -eEuo pipefail

if [ $# -ne 2 ]; then
    echo "Usage: ${0} PUBLIC_HOSTNAME PUBLIC_ISSUER_HOSTNAME" >&2
    exit 1
fi

K3S_HOSTNAME="${1}"
K3S_API_PORT=6443
PUBLIC_ISSUER_HOSTNAME="${2}"

export INSTALL_K3S_SKIP_DOWNLOAD=true

echo "Using hostname ${K3S_HOSTNAME} as SAN" >&2
echo "Using ${PUBLIC_ISSUER_HOSTNAME} as service account issuer" >&2

curl -sfL https://get.k3s.io | sh -s - \
    server \
    --tls-san 127.0.0.1 \
    --tls-san "${K3S_HOSTNAME}" \
    --kube-apiserver-arg="service-account-jwks-uri=https://${PUBLIC_ISSUER_HOSTNAME}/openid/v1/jwks" \
    --kube-apiserver-arg="service-account-issuer=https://${PUBLIC_ISSUER_HOSTNAME}" \
    --kube-apiserver-arg="service-account-issuer=https://${K3S_HOSTNAME}:${K3S_API_PORT}" \
    --kube-apiserver-arg="api-audiences=sts.amazonaws.com" \
    --kube-apiserver-arg="anonymous-auth=true"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

for _ in $(seq 1 20); do
    if kubectl get IngressRoute >/dev/null 2>&1;then
        echo "API server is ready" >&2
        touch /tmp/k8s-ready
        break
    fi

    echo "API server is not ready...">&2
    sleep 10
done

if ! [ -f /tmp/k8s-ready ]; then
    echo "K8s control plane did not become ready in time!" >&2
    exit 1
fi

echo "Enabling anonymous access to OIDC discovery endpoints" >&2
sed "s|ISSUER_HOSTNAME|${PUBLIC_ISSUER_HOSTNAME}|g" /root/oidc-anonymous-access.yaml | kubectl apply -f -

