# Grafana Deployment — Design Spec

**Date:** 2026-04-04
**Scope:** Management cluster only. Enable Grafana via the kube-prometheus-stack built-in subchart.

---

## Overview

Enable Grafana on the management k3s cluster by re-enabling the Grafana subchart within the existing `kube-prometheus-stack` Helm chart. Grafana stores its configuration (dashboards, users, sessions) in a local SQLite database backed by a persistent volume. It is exposed via a Traefik ingress at `grafana.fergal.website`, proxied through Cloudflare. The Prometheus datasource and default cluster dashboards are auto-provisioned by the chart.

---

## Architecture

```
Browser
  ↓ HTTPS (Cloudflare proxied)
Cloudflare
  ↓
Traefik ingress (ingressClassName: traefik)
  ↓
Grafana pod (kube-prometheus-stack namespace)
  ↓ queries
Prometheus (in-cluster, kube-prometheus-stack namespace)
  ↓
SQLite (PVC, 1Gi)
```

---

## Components

### 1. `deployments/management/charts/kube-prometheus-stack.yaml` — Grafana values

The only file that changes. The `grafana:` section is updated from `enabled: false` to the following:

**Enable:**
```yaml
grafana:
  enabled: true
```

**Persistence** — SQLite database stored in a 1Gi PVC:
```yaml
  persistence:
    enabled: true
    size: 1Gi
```
SQLite only stores dashboard definitions, user accounts, and sessions — not metrics data — so 1Gi is sufficient.

**Ingress** — Traefik, Cloudflare-proxied, TLS (same pattern as ArgoCD):
```yaml
  ingress:
    enabled: true
    ingressClassName: traefik
    hosts:
      - grafana.fergal.website
    tls:
      - hosts:
          - grafana.fergal.website
```
external-dns creates a Cloudflare-proxied A record for `grafana.fergal.website` (proxying is enabled globally in the external-dns chart).

**Admin credentials** — not set explicitly; Grafana generates a random password on first deploy and stores it in the secret `kube-prometheus-stack-grafana` (keys: `admin-user`, `admin-password`).

To retrieve: `kubectl get secret -n kube-prometheus-stack kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d`

Credentials can be migrated to an ExternalSecret from AWS Secrets Manager later without any architectural change.

**Resources** — conservative sizing, consistent with other charts:
```yaml
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      memory: 128Mi
```

### 2. Auto-provisioned: Prometheus datasource

The kube-prometheus-stack chart automatically provisions a Prometheus datasource pointing to:
```
http://kube-prometheus-stack-prometheus.kube-prometheus-stack.svc:9090
```
No manual datasource configuration required. This assumes Prometheus is running in standard mode (not agent mode) so it is queryable — the Prometheus migration out of agent mode is handled separately.

### 3. Auto-provisioned: Default dashboards

The chart's sidecar (grafana-sc-dashboard) watches for ConfigMaps labelled `grafana_dashboard: "1"` and loads them at runtime. kube-prometheus-stack ships ConfigMaps for:
- Kubernetes cluster / node / pod / namespace metrics
- kube-state-metrics
- node-exporter
- Prometheus self-monitoring

No additional dashboard configuration required.

---

## Data Flow

1. User navigates to `grafana.fergal.website`.
2. Cloudflare terminates TLS, proxies request to Traefik ingress.
3. Traefik routes to the Grafana service in `kube-prometheus-stack` namespace.
4. Grafana serves the UI; reads dashboard/user state from SQLite on the PVC.
5. Dashboard queries are executed against the in-cluster Prometheus via the auto-provisioned datasource.

---

## Not in Scope

- Migrating Prometheus out of agent mode (prerequisite, handled separately)
- Decommissioning Mimir (handled separately)
- AlertManager / alerting rules
- SMTP / notification channels
- ExternalSecret-backed admin credentials (can be added later)

---

## Future Considerations

- Migrate admin credentials to ExternalSecret from AWS Secrets Manager
- Add additional datasources (Loki, Tempo) as they are deployed
- Configure SMTP for alert notifications
