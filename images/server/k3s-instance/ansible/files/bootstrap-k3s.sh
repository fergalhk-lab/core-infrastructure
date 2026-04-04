#!/usr/bin/env bash

set -eEuo pipefail

if [ $# -ne 3 ]; then
    echo "Usage: ${0} PUBLIC_HOSTNAME PUBLIC_ISSUER_HOSTNAME ECR_ROLE_ARN" >&2
    exit 1
fi

K3S_HOSTNAME="${1}"
K3S_API_PORT=6443
PUBLIC_ISSUER_HOSTNAME="${2}"
ECR_ROLE_ARN="${3}"

echo "Writing ECR credential provider config" >&2
mkdir -p /var/lib/rancher/credentialprovider
install -m 0600 /dev/null /var/lib/rancher/credentialprovider/config.yaml

# Extract account ID from role ARN (arn:aws:iam::<account-id>:role/...)
AWS_ACCOUNT_ID=$(echo "${ECR_ROLE_ARN}" | cut -d: -f5)

cat > /var/lib/rancher/credentialprovider/config.yaml <<EOF
apiVersion: kubelet.config.k8s.io/v1
kind: CredentialProviderConfig
providers:
  - name: ecr-credential-provider
    matchImages:
      - "${AWS_ACCOUNT_ID}.dkr.ecr.*.amazonaws.com"
    defaultCacheDuration: "12h"
    apiVersion: credentialprovider.kubelet.k8s.io/v1
    tokenAttributes:
      serviceAccountTokenAudiences:
        - sts.amazonaws.com
      requireServiceAccount: true
    env:
      - name: AWS_ROLE_ARN
        value: "${ECR_ROLE_ARN}"
      - name: AWS_REGION
        value: "eu-west-1"
EOF

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
    --kube-apiserver-arg="anonymous-auth=true" \
    --kubelet-arg="image-credential-provider-config=/var/lib/rancher/credentialprovider/config.yaml" \
    --kubelet-arg="image-credential-provider-bin-dir=/var/lib/rancher/credentialprovider/bin"

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

