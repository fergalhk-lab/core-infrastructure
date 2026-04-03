# cert-manager — Design

## Overview

Deploy cert-manager to the `management` cluster for use as internal cluster PKI. Follows the existing rendered-manifests pattern: a single chart YAML config file rendered via `helm template` and applied with `kubectl apply --server-side`.

## What Is Being Deployed

cert-manager from the official Jetstack Helm chart. CRDs are managed by the chart itself (`crds.enabled: true`). No `ClusterIssuer` or other issuer objects are included — those will be configured separately.

## File To Create

```
cluster-config/management/charts/cert-manager.yaml
```

```yaml
name: cert-manager
namespace: cert-manager
chart:
  source: https://charts.jetstack.io
  name: cert-manager
  version: <latest stable v1.x>
values:
  crds:
    enabled: true
  resources:
    requests:
      cpu: 10m
      memory: 64Mi
    limits:
      memory: 64Mi
  webhook:
    resources:
      requests:
        cpu: 5m
        memory: 32Mi
      limits:
        memory: 32Mi
  cainjector:
    resources:
      requests:
        cpu: 5m
        memory: 64Mi
      limits:
        memory: 64Mi
```

## Deployment

```
util/deploy-chart.sh cluster-config/management/charts/cert-manager.yaml
```

This creates the `cert-manager` namespace if absent, renders the Helm chart, and applies manifests server-side.

## Constraints

- Follows the rendered-manifests pattern; no direct `kubectl apply` outside the deploy-chart.sh script.
- Terraform is run via pipeline only — no local terraform commands.
- Targets the `management` cluster only.
- No issuers are provisioned as part of this deployment.
