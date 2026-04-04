#!/usr/bin/env bash

set -eEuo pipefail

if [ $# -ne 4 ]; then
    echo "Usage: ${0} PUBLIC_HOSTNAME PUBLIC_ISSUER_HOSTNAME ECR_ROLE_ARN STORAGE_VOLUME_ID" >&2
    exit 1
fi

K3S_HOSTNAME="${1}"
K3S_API_PORT=6443
PUBLIC_ISSUER_HOSTNAME="${2}"
ECR_ROLE_ARN="${3}"
STORAGE_VOLUME_ID="${4}"

if [[ ! "${STORAGE_VOLUME_ID}" =~ ^[0-9]+$ ]]; then
    echo "STORAGE_VOLUME_ID must be numeric, got: ${STORAGE_VOLUME_ID}" >&2
    exit 1
fi

STORAGE_DEVICE="/dev/disk/by-id/scsi-0HC_Volume_${STORAGE_VOLUME_ID}"
STORAGE_MOUNT="/mnt/k3s-data"
MOUNT_UNIT="$(systemd-escape --path "${STORAGE_MOUNT}").mount"

echo "Writing ECR credential provider config" >&2
mkdir -p /var/lib/rancher/credentialprovider

# Extract account ID from role ARN (arn:aws:iam::<account-id>:role/...)
AWS_ACCOUNT_ID=$(echo "${ECR_ROLE_ARN}" | cut -d: -f5)

(
    umask 0177
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
      serviceAccountTokenAudience: sts.amazonaws.com
      requireServiceAccount: true
    env:
      - name: AWS_ROLE_ARN
        value: "${ECR_ROLE_ARN}"
      - name: AWS_REGION
        value: "eu-west-1"
EOF
)

echo "Waiting for storage volume ${STORAGE_VOLUME_ID} at ${STORAGE_DEVICE}" >&2
for _ in $(seq 1 30); do
    [ -b "${STORAGE_DEVICE}" ] && break
    sleep 2
done
if ! [ -b "${STORAGE_DEVICE}" ]; then
    echo "Storage volume ${STORAGE_VOLUME_ID} never appeared at ${STORAGE_DEVICE}" >&2
    exit 1
fi

mkdir -p "${STORAGE_MOUNT}"

cat > "/etc/systemd/system/${MOUNT_UNIT}" <<UNIT
[Unit]
Description=Mount k3s storage volume at ${STORAGE_MOUNT}
Before=k3s.service

[Mount]
What=${STORAGE_DEVICE}
Where=${STORAGE_MOUNT}
# Type must match format=ext4 set on hcloud_volume in Terraform
Type=ext4
Options=defaults,noatime

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now "${MOUNT_UNIT}"
echo "Mounted volume ${STORAGE_VOLUME_ID} at ${STORAGE_MOUNT}" >&2

mkdir -p "${STORAGE_MOUNT}/db" "${STORAGE_MOUNT}/tls" "${STORAGE_MOUNT}/storage"

mkdir -p /var/lib/rancher/k3s/server
ln -sfn "${STORAGE_MOUNT}/db"      /var/lib/rancher/k3s/server/db
ln -sfn "${STORAGE_MOUNT}/tls"     /var/lib/rancher/k3s/server/tls
ln -sfn "${STORAGE_MOUNT}/storage" /var/lib/rancher/k3s/storage

echo "Writing k3s volume mount drop-in" >&2
mkdir -p /etc/systemd/system/k3s.service.d
cat > /etc/systemd/system/k3s.service.d/volumes.conf <<DROPIN
[Unit]
After=${MOUNT_UNIT}
Requires=${MOUNT_UNIT}
DROPIN
systemctl daemon-reload

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
    --kubelet-arg="image-credential-provider-bin-dir=/var/lib/rancher/credentialprovider/bin" \
    --kubelet-arg="feature-gates=KubeletServiceAccountTokenForCredentialProviders"


export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

for _ in $(seq 1 20); do
    if kubectl get IngressRoute >/dev/null 2>&1; then
        echo "API server is ready" >&2
        touch /tmp/k8s-ready
        break
    fi

    echo "API server is not ready..." >&2
    sleep 10
done

if ! [ -f /tmp/k8s-ready ]; then
    echo "K8s control plane did not become ready in time!" >&2
    exit 1
fi

echo "Enabling anonymous access to OIDC discovery endpoints" >&2
sed "s|ISSUER_HOSTNAME|${PUBLIC_ISSUER_HOSTNAME}|g" /root/oidc-anonymous-access.yaml | kubectl apply -f -
