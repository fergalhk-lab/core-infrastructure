#!/usr/bin/env bash

set -eEuo pipefail

if [ $# -ne 6 ]; then
    echo "Usage: ${0} PUBLIC_HOSTNAME PUBLIC_ISSUER_HOSTNAME ECR_ROLE_ARN ETCD_VOLUME_ID TLS_VOLUME_ID PVS_VOLUME_ID" >&2
    exit 1
fi

K3S_HOSTNAME="${1}"
K3S_API_PORT=6443
PUBLIC_ISSUER_HOSTNAME="${2}"
ECR_ROLE_ARN="${3}"
ETCD_VOLUME_ID="${4}"
TLS_VOLUME_ID="${5}"
PVS_VOLUME_ID="${6}"

VOLUMES=(
    "${ETCD_VOLUME_ID}:/var/lib/rancher/k3s/server/db"
    "${TLS_VOLUME_ID}:/var/lib/rancher/k3s/server/tls"
    "${PVS_VOLUME_ID}:/var/lib/rancher/k3s/storage"
)

mount_k3s_volume() {
    local volume_id="${1}"
    local mount_point="${2}"
    local device="/dev/disk/by-id/scsi-0HC_Volume_${volume_id}"

    echo "Waiting for volume ${volume_id} at ${device}" >&2
    for _ in $(seq 1 30); do
        [ -b "${device}" ] && break
        sleep 2
    done
    if ! [ -b "${device}" ]; then
        echo "Volume ${volume_id} never appeared at ${device}" >&2
        exit 1  # exits the entire script (bash exit always exits the process)
    fi

    mkdir -p "${mount_point}"

    local unit_name
    unit_name="$(systemd-escape --path "${mount_point}").mount"

    cat > "/etc/systemd/system/${unit_name}" <<UNIT
[Unit]
Description=Mount k3s volume at ${mount_point}
Before=k3s.service

[Mount]
What=${device}
Where=${mount_point}
# Type must match format=ext4 set on hcloud_volume in Terraform
Type=ext4
Options=defaults

[Install]
WantedBy=multi-user.target
UNIT

    echo "Written unit ${unit_name} for ${mount_point}" >&2
}

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

echo "Mounting k3s volumes" >&2
for vol_spec in "${VOLUMES[@]}"; do
    volume_id="${vol_spec%%:*}"
    mount_point="${vol_spec##*:}"
    mount_k3s_volume "${volume_id}" "${mount_point}"
done
systemctl daemon-reload
for vol_spec in "${VOLUMES[@]}"; do
    volume_id="${vol_spec%%:*}"
    mount_point="${vol_spec##*:}"
    unit_name="$(systemd-escape --path "${mount_point}").mount"
    systemctl enable --now "${unit_name}"
    echo "Mounted volume ${volume_id} at ${mount_point}" >&2
done

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

# This drop-in only takes effect on subsequent boots; on first boot the volumes
# are already mounted before k3s starts.
echo "Writing k3s volume mount drop-in" >&2
mkdir -p /etc/systemd/system/k3s.service.d
cat > /etc/systemd/system/k3s.service.d/volumes.conf <<DROPIN
[Unit]
After=var-lib-rancher-k3s-server-db.mount var-lib-rancher-k3s-server-tls.mount var-lib-rancher-k3s-storage.mount
Requires=var-lib-rancher-k3s-server-db.mount var-lib-rancher-k3s-server-tls.mount var-lib-rancher-k3s-storage.mount
DROPIN
systemctl daemon-reload

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

for _ in $(seq 1 20); do
    if kubectl get IngressRoute >/dev/null 2>&1; then
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
