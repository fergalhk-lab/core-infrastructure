# Mimir Decommission & Prometheus Local Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decommission Mimir and all its AWS infrastructure, and switch Prometheus from agent mode to full TSDB mode with 7-day local retention on a 20Gi PVC.

**Architecture:** Single PR removes the Mimir Helm chart, reconfigures kube-prometheus-stack to store data locally, and deletes the supporting Terraform resources (S3 bucket, IAM role, data sources). Manual prerequisite: empty the `fergalhk-mimir` S3 bucket before running the pipeline so Terraform can delete it without `force_destroy`.

**Tech Stack:** Helm chart values (YAML), Terraform (HCL), kube-prometheus-stack v82.17.0, Kubernetes StorageClass `local-path`

---

## PREREQUISITE (manual — do before starting)

Empty the `fergalhk-mimir` S3 bucket via the AWS console or CLI. Terraform cannot delete a non-empty bucket. This must be done before the pipeline runs.

---

## File Map

| Action | File |
|--------|------|
| Delete | `deployments/management/charts/mimir.yaml` |
| Modify | `deployments/management/charts/kube-prometheus-stack.yaml` |
| Delete | `foundation/aws/platform/mimir.tf` |
| Delete | `foundation/hetzner/management/_data-s3.tf` |
| Modify | `foundation/hetzner/management/k8s-roles.tf` |

---

### Task 1: Create worktree

- [ ] **Step 1: Create and enter worktree**

```bash
git worktree add .worktrees/decommission-mimir -b decommission-mimir main
cd .worktrees/decommission-mimir
```

---

### Task 2: Remove Mimir Helm chart

**Files:**
- Delete: `deployments/management/charts/mimir.yaml`

- [ ] **Step 1: Delete the Mimir chart config**

```bash
rm deployments/management/charts/mimir.yaml
```

- [ ] **Step 2: Verify the file is gone and no other chart references Mimir**

```bash
ls deployments/management/charts/
grep -r "mimir" deployments/ --include="*.yaml"
```

Expected: `mimir.yaml` not listed. The grep should produce no output.

- [ ] **Step 3: Commit**

```bash
git add deployments/management/charts/mimir.yaml
git commit -m "feat: remove Mimir helm chart"
```

---

### Task 3: Reconfigure Prometheus to local storage mode

**Files:**
- Modify: `deployments/management/charts/kube-prometheus-stack.yaml`

- [ ] **Step 1: Replace the file contents**

Write `deployments/management/charts/kube-prometheus-stack.yaml` with exactly:

```yaml
name: kube-prometheus-stack
namespace: kube-prometheus-stack
chart:
  source: https://prometheus-community.github.io/helm-charts
  name: kube-prometheus-stack
  version: 82.17.0
values:
  # Grafana is out of scope for this iteration.
  # Add a separate grafana chart config when visualization is needed.
  grafana:
    enabled: false

  # AlertManager disabled — no alerting configured yet.
  alertmanager:
    enabled: false

  prometheus:
    prometheusSpec:
      retention: 7d

      storageSpec:
        volumeClaimTemplate:
          spec:
            storageClassName: local-path
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 20Gi

      resources:
        requests:
          cpu: 50m
          memory: 256Mi
        limits:
          memory: 512Mi

  # kube-state-metrics and node-exporter are enabled by default.
  # The chart creates ServiceMonitors for both automatically.
  kube-state-metrics:
    resources:
      requests:
        cpu: 10m
        memory: 64Mi
      limits:
        memory: 64Mi

  # prometheus-node-exporter is the sub-chart name; resources go here, not under nodeExporter:
  prometheus-node-exporter:
    resources:
      requests:
        cpu: 5m
        memory: 32Mi
      limits:
        memory: 32Mi

  prometheusOperator:
    resources:
      requests:
        cpu: 10m
        memory: 64Mi
      limits:
        memory: 64Mi
```

- [ ] **Step 2: Validate YAML syntax**

```bash
python3 -c "import yaml, sys; yaml.safe_load(open('deployments/management/charts/kube-prometheus-stack.yaml')); print('OK')"
```

Expected: `OK`

- [ ] **Step 3: Confirm agent mode and remoteWrite are gone**

```bash
grep -E "agent|remoteWrite|mimir" deployments/management/charts/kube-prometheus-stack.yaml
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add deployments/management/charts/kube-prometheus-stack.yaml
git commit -m "feat: switch Prometheus from agent mode to local TSDB storage"
```

---

### Task 4: Remove Mimir S3 bucket Terraform

**Files:**
- Delete: `foundation/aws/platform/mimir.tf`

- [ ] **Step 1: Delete the file**

```bash
rm foundation/aws/platform/mimir.tf
```

- [ ] **Step 2: Confirm no remaining references to the bucket resource in this module**

```bash
grep -r "aws_s3_bucket.mimir\|fergalhk-mimir" foundation/aws/ --include="*.tf"
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add foundation/aws/platform/mimir.tf
git commit -m "feat: remove Mimir S3 bucket Terraform resources"
```

---

### Task 5: Remove Mimir IAM and data source Terraform

**Files:**
- Delete: `foundation/hetzner/management/_data-s3.tf`
- Modify: `foundation/hetzner/management/k8s-roles.tf`

- [ ] **Step 1: Delete the Mimir S3 data source file**

```bash
rm foundation/hetzner/management/_data-s3.tf
```

- [ ] **Step 2: Replace k8s-roles.tf, removing only the Mimir resources**

Write `foundation/hetzner/management/k8s-roles.tf` with exactly:

```hcl
module "hello_world_role" {
  source = "./modules/pod-role"

  oidc_provider_arn    = aws_iam_openid_connect_provider.management_k8s.arn
  oidc_issuer_url      = aws_iam_openid_connect_provider.management_k8s.url
  namespace            = "hello-world"
  service_account_name = "fergal"
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = ["*"]
  }
}

module "external_secrets_role" {
  source = "./modules/pod-role"

  oidc_provider_arn    = aws_iam_openid_connect_provider.management_k8s.arn
  oidc_issuer_url      = aws_iam_openid_connect_provider.management_k8s.url
  namespace            = "external-secrets"
  service_account_name = "external-secrets"
  policy_document      = data.aws_iam_policy_document.external_secrets.json
}
```

- [ ] **Step 3: Confirm no remaining Mimir references in the hetzner management module**

```bash
grep -r "mimir" foundation/hetzner/ --include="*.tf"
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add foundation/hetzner/management/_data-s3.tf foundation/hetzner/management/k8s-roles.tf
git commit -m "feat: remove Mimir IAM role and S3 data source Terraform"
```

---

### Task 6: Final verification

- [ ] **Step 1: Check for any remaining Mimir references across the whole repo**

```bash
grep -r "mimir" deployments/ foundation/ --include="*.yaml" --include="*.tf" -l
```

Expected: no files listed.

- [ ] **Step 2: Validate all remaining chart YAML files parse cleanly**

```bash
for f in deployments/management/charts/*.yaml; do
  python3 -c "import yaml; yaml.safe_load(open('$f'))" && echo "OK: $f" || echo "FAIL: $f"
done
```

Expected: `OK` for every file, no `FAIL`.

- [ ] **Step 3: Push branch for PR**

```bash
git push -u origin decommission-mimir
```
