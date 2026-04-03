# Cluster API Operator — Design

## Overview

Deploy the cluster-api-operator and required CAPI providers to the `management` cluster, using the existing rendered-manifests pattern (chart YAML → `helm template` → ArgoCD).

## What Is Being Deployed

The cluster-api-operator is a meta-operator that manages the lifecycle of CAPI provider components. Rather than installing CAPI core/bootstrap/control-plane/infrastructure directly, the operator reads Provider custom resources and installs the correct component versions on its behalf.

Four providers are required:

| Kind | Name | Namespace | Purpose |
|---|---|---|---|
| `CoreProvider` | `cluster-api` | `capi-system` | CAPI core controllers |
| `BootstrapProvider` | `kubeadm` | `capi-kubeadm-bootstrap-system` | Kubeadm bootstrap |
| `ControlPlaneProvider` | `kubeadm` | `capi-kubeadm-control-plane-system` | Kubeadm control plane |
| `InfrastructureProvider` | `hetzner` | `caph-system` | Hetzner (CAPH) infrastructure |

## File To Create

```
cluster-config/management/charts/cluster-api-operator.yaml
```

Following the existing pattern (see `cluster-config/management/charts/argocd.yaml`):

```yaml
name: cluster-api-operator
namespace: capi-operator-system
chart:
  source: https://kubernetes-sigs.github.io/cluster-api-operator/
  name: cluster-api-operator
  version: <latest stable>
values:
  extraObjects:
    - apiVersion: operator.cluster.x-k8s.io/v1alpha2
      kind: CoreProvider
      metadata:
        name: cluster-api
        namespace: capi-system
      spec:
        version: <latest stable>
    - apiVersion: operator.cluster.x-k8s.io/v1alpha2
      kind: BootstrapProvider
      metadata:
        name: kubeadm
        namespace: capi-kubeadm-bootstrap-system
      spec:
        version: <latest stable>
    - apiVersion: operator.cluster.x-k8s.io/v1alpha2
      kind: ControlPlaneProvider
      metadata:
        name: kubeadm
        namespace: capi-kubeadm-control-plane-system
      spec:
        version: <latest stable>
    - apiVersion: operator.cluster.x-k8s.io/v1alpha2
      kind: InfrastructureProvider
      metadata:
        name: hetzner
        namespace: caph-system
      spec:
        version: <latest stable>
```

## Hetzner Token Secret

CAPH requires a Kubernetes secret containing the Hetzner API token in the `caph-system` namespace. This is provided via an `ExternalSecret` extraObject, following the same pattern as ArgoCD's GitHub credentials.

- **ClusterSecretStore**: `aws-secrets-manager` (already deployed on the cluster)
- **AWS Secrets Manager key**: `apikeys/hetzner/management`
- **Target secret name**: `hetzner` in namespace `caph-system`
- **Secret key**: `hcloud-token`

This ExternalSecret is added alongside the Provider CRs in the `extraObjects` list.

## Versions

Specific versions for the operator chart and each provider must be looked up at implementation time:

- Operator chart: https://github.com/kubernetes-sigs/cluster-api-operator/releases
- CAPI core/kubeadm providers: https://github.com/kubernetes-sigs/cluster-api/releases
- CAPH (Hetzner): https://github.com/syself/cluster-api-provider-hetzner/releases

## Constraints

- Terraform is run via pipeline only — no local terraform commands.
- Follows the rendered-manifests pattern; no direct `kubectl apply`.
- Targets the `management` cluster only.
