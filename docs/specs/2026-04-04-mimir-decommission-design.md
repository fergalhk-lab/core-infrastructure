# Mimir Decommission & Prometheus Local Storage

**Date:** 2026-04-04

## Summary

Decommission Mimir (mimir-distributed) and its supporting AWS infrastructure, and reconfigure Prometheus from agent-only mode to full TSDB mode with local storage. Existing Mimir data is discarded.

## Approach

Single PR — manual prerequisite: empty the `fergalhk-mimir` S3 bucket via AWS console/CLI before merging, so Terraform can delete it without `force_destroy`.

## Kubernetes / Helm Changes

### Delete `deployments/management/charts/mimir.yaml`

Removes all Mimir components from the cluster (ingester, distributor, querier, query_frontend, query_scheduler, store_gateway, compactor).

### Modify `deployments/management/charts/kube-prometheus-stack.yaml`

| Change | Detail |
|--------|--------|
| Remove `enableFeatures: [agent]` | Switches Prometheus to full TSDB mode |
| Remove `storageSpec: {}` | Replaced with PVC-backed storage |
| Add `storageSpec` | 20Gi PVC, StorageClass `local-path`, `ReadWriteOnce` |
| Add `retention: 7d` | 7-day local retention |
| Remove `remoteWrite` block | No longer writing to Mimir gateway |

`alertmanager` remains disabled. No other changes to kube-state-metrics, node-exporter, or prometheusOperator.

## Terraform Changes

### Delete `foundation/aws/platform/mimir.tf`

Removes:
- `aws_s3_bucket.mimir` (`fergalhk-mimir`)
- `aws_s3_bucket_server_side_encryption_configuration.mimir`
- `aws_s3_bucket_public_access_block.mimir`

### Delete `foundation/hetzner/management/_data-s3.tf`

Entire file — only contained `data "aws_s3_bucket" "mimir"`.

### Modify `foundation/hetzner/management/k8s-roles.tf`

Remove:
- `data "aws_iam_policy_document" "mimir"`
- `module "mimir_role"`

Keep untouched:
- `module "hello_world_role"`
- `data "aws_iam_policy_document" "external_secrets"`
- `module "external_secrets_role"`

## Prerequisites

1. Empty the `fergalhk-mimir` S3 bucket manually before running the pipeline.

## Out of Scope

- Grafana (already disabled, no change)
- Alertmanager (already disabled, no change)
- Any alerting rules or recording rules (none currently configured)
