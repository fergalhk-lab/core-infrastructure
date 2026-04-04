---
name: tune-container-resources
description: Use when tuning Kubernetes container CPU and memory requests/limits for containers in this cluster. Triggered when resource utilization looks off, after deployments, or on a regular maintenance cadence.
---

# Tune Container Resources

## Overview

Query Prometheus for live CPU and memory utilization, compare against target ranges, update Helm chart values in `deployments/`, and ask the user to deploy.

## Step 1: Connect to Prometheus

```bash
kubectl -n kube-prometheus-stack port-forward prometheus-kube-prometheus-stack-prometheus-0 9090:9090 &
sleep 3
```

## Step 2: Query Utilization

**CPU % of request:**
```bash
curl -s 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=100 * max by (container, pod, namespace) (rate(container_cpu_usage_seconds_total{container!=""}[1m])) / max by (container, pod, namespace) (kube_pod_container_resource_requests{container!="", resource="cpu"})' \
  | jq -r '["NAMESPACE","CONTAINER","CPU%"] , (.data.result | sort_by(.value[1] | tonumber) | reverse | .[] | [.metric.namespace, .metric.container, (.value[1] | tonumber | . * 10 | round / 10 | tostring + "%")]) | @tsv' \
  | column -t
```

**Memory % of request:**
```bash
curl -s 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=100 * max by (container, pod, namespace) (container_memory_rss{container!=""}) / max by (container, pod, namespace) (kube_pod_container_resource_requests{container!="", resource="memory"})' \
  | jq -r '["NAMESPACE","CONTAINER","MEM%"] , (.data.result | sort_by(.value[1] | tonumber) | reverse | .[] | [.metric.namespace, .metric.container, (.value[1] | tonumber | . * 10 | round / 10 | tostring + "%")]) | @tsv' \
  | column -t
```

**Actual usage (for over-provisioning assessment):**
```bash
# CPU in millicores
curl -s 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=max by (container, namespace) (rate(container_cpu_usage_seconds_total{container!=""}[5m])) * 1000' \
  | jq -r '["NS","CONTAINER","mCPU"] , (.data.result | sort_by(.value[1] | tonumber) | reverse | .[] | [.metric.namespace, .metric.container, (.value[1] | tonumber | . * 10 | round / 10 | tostring + "m")]) | @tsv' | column -t

# Memory RSS in MiB
curl -s 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=max by (container, namespace) (container_memory_rss{container!=""}) / 1024 / 1024' \
  | jq -r '["NS","CONTAINER","MiB"] , (.data.result | sort_by(.value[1] | tonumber) | reverse | .[] | [.metric.namespace, .metric.container, (.value[1] | tonumber | . * 10 | round / 10 | tostring + "Mi")]) | @tsv' | column -t
```

## Step 3: Check for Trends

For any container above the ceiling or suspiciously low, check a 6h range:

```bash
# Replace <container> and <namespace> as needed
curl -s 'http://localhost:9090/api/v1/query_range' \
  --data-urlencode 'query=100 * max by (container) (container_memory_rss{container="<container>", namespace="<namespace>"}) / max by (container) (kube_pod_container_resource_requests{container="<container>", namespace="<namespace>", resource="memory"})' \
  --data-urlencode 'start='"$(date -d '6 hours ago' +%s)" \
  --data-urlencode 'end='"$(date +%s)" \
  --data-urlencode 'step=600' \
  | jq '[.data.result[0].values[] | {t: (.[0] | strftime("%H:%M")), v: (.[1] | tonumber | . * 10 | round / 10)}] | .[]'
```

**If values are creeping steadily upward over hours: raise with the user** — this may indicate a leak or unbounded cache, not just under-provisioning.

If values oscillate (e.g. prometheus WAL compaction cycles), that's normal — just tune to the right range.

## Step 4: Sizing Rules

| Metric | Target range | Action if outside |
|--------|-------------|-------------------|
| CPU steady-state | 70–90% | Adjust CPU request |
| Memory steady-state | 40–70% | Adjust memory request |

**Small container exceptions** (current allocation < 64Mi memory OR < 100m CPU): lean towards higher provisioning rather than tuning tightly to the target range.

**Constraints — always enforce:**
- `limits.memory` MUST equal `requests.memory`
- CPU must have **no limits**, only requests
- Every pod must have both CPU and memory set

**CPU bursts over 100% are fine** — do not provision for them.

## Step 5: Update Charts

Chart files are in `deployments/management/charts/`. Update the relevant `resources:` blocks.

## Step 6: Ask User to Deploy

After updating charts, present a summary of changes and ask the user to review, then run:

```bash
util/deploy-all-charts.sh deployments/management/charts/
```
