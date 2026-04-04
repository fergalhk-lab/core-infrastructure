# Mimir Module Extraction Design

**Date:** 2026-04-04

> **Note for LLMs implementing this plan:** Terraform is run via pipeline only — never run `terraform` commands locally or suggest doing so. For any step that requires a Terraform apply, instruct the user to commit and push the changes so the pipeline runs. For the state migration script, write the script and tell the user to run it themselves.

## Problem

Mimir-related resources are currently split across two unrelated root modules:

- `foundation/aws/platform/mimir.tf` — S3 bucket and bucket configuration
- `foundation/hetzner/management/k8s-roles.tf` — IAM role, policy document, S3 data source
- `foundation/hetzner/management/outputs.tf` — `mimir_role_arn` output
- `foundation/hetzner/management/modules/pod-role/` — IRSA role module, local-only

This breaks the principle that each module should be focused. The pod-role module is also not reusable across clusters since its role naming hardcodes `k8s-mgmt-`.

## Goal

Extract all Mimir infrastructure into `foundation/observability/mimir`, a new focused root module. Make the pod-role module common and genuinely multi-cluster capable. Introduce an SSM-based contract for K8s cluster metadata so consumers can look up OIDC configuration without cross-state references or hardcoded conventions.

## Approach

Approach C was selected: explicit SSM contract. Both `oidc_issuer_url` and `oidc_provider_arn` are written to SSM by `hetzner/management`, and read back by consumers. This avoids ARN reconstruction in consumers and makes the contract explicit and self-documenting.

---

## Module Structure

### New: `foundation/observability/mimir/`

A root module (added to `config/terraform.yaml`). Owns all Mimir infrastructure.

```
foundation/observability/mimir/
  versions.tf     # aws provider ~> 5.0
  variables.tf    # cluster_provider, cluster_name, bucket_name — all required, no defaults
  _data.tf        # SSM parameter reads, aws_s3_bucket data source
  s3.tf           # aws_s3_bucket, encryption config, public access block
  iam.tf          # aws_iam_policy_document.mimir + module.mimir_role
  outputs.tf      # mimir_role_arn
```

Variables:

| Name | Type | Description |
|---|---|---|
| `cluster_provider` | `string` | K8s cluster provider (e.g. `hetzner`) |
| `cluster_name` | `string` | K8s cluster name (e.g. `management`) |
| `bucket_name` | `string` | Name of the Mimir S3 bucket |

No defaults — the module is explicitly cluster-agnostic.

State key (auto-derived by `util/terraform.sh`): `core-infrastructure/foundation/observability/mimir/terraform.tfstate`

### Moved: `common/tfmodules/aws/pod-role/`

Relocated from `foundation/hetzner/management/modules/pod-role/`. Gains one new required variable:

| Name | Type | Description |
|---|---|---|
| `cluster_name` | `string` | K8s cluster name — used in IAM role naming |

Role naming changes from `k8s-mgmt-{namespace}-{sa}` to `k8s-{cluster_name}-{namespace}-{sa}`.

For the management cluster this produces `k8s-management-{namespace}-{sa}`. Existing `k8s-mgmt-*` roles are renamed via `state mv` in the migration script (no AWS-side change).

### Updated: `foundation/hetzner/management/`

**Added:**
- `ssm.tf` — writes two SSM parameters after OIDC provider is created

**Updated:**
- `k8s-roles.tf` — remove mimir role, policy doc; update remaining roles to use `common/tfmodules/aws/pod-role` with `cluster_name = "management"`

**Deleted:**
- `_data-s3.tf`
- `outputs.tf`
- `modules/pod-role/`

### Updated: `foundation/aws/platform/`

**Deleted:**
- `mimir.tf`

### Updated: `config/terraform.yaml`

```yaml
modules:
  - foundation/terraform-state-backend
  - foundation/aws/platform
  - edge/zones
  - foundation/hetzner/management
  - foundation/observability/mimir    # new
```

---

## SSM Contract

`foundation/hetzner/management` writes two `String` SSM parameters after `aws_iam_openid_connect_provider.management_k8s` is created:

```
/k8s/hetzner/management/oidc_issuer_url   = "https://issuer-k8s-management.fergal.website"
/k8s/hetzner/management/oidc_provider_arn = "arn:aws:iam::740994137039:oidc-provider/issuer-k8s-management.fergal.website"
```

Path convention: `/k8s/{cluster_provider}/{cluster_name}/{key}`

Both are `String` type (not `SecureString` — these are non-sensitive public identifiers).

`foundation/observability/mimir` resolves its OIDC configuration entirely via data sources:

```hcl
locals {
  ssm_prefix = "/k8s/${var.cluster_provider}/${var.cluster_name}"
}

data "aws_ssm_parameter" "oidc_issuer_url" {
  name = "${local.ssm_prefix}/oidc_issuer_url"
}

data "aws_ssm_parameter" "oidc_provider_arn" {
  name = "${local.ssm_prefix}/oidc_provider_arn"
}
```

These are passed directly into the pod-role module. The mimir module has zero hardcoded AWS account or cluster knowledge.

---

## State Migration

Resources are moved between state files — no AWS-side destroy/recreate.

### Resources moved: `foundation/aws/platform` → `foundation/observability/mimir`

| Resource |
|---|
| `aws_s3_bucket.mimir` |
| `aws_s3_bucket_server_side_encryption_configuration.mimir` |
| `aws_s3_bucket_public_access_block.mimir` |

### Resources moved: `foundation/hetzner/management` → `foundation/observability/mimir`

| Resource |
|---|
| `module.mimir_role.aws_iam_role.this` |
| `module.mimir_role.aws_iam_role_policy.this[0]` |

### IAM role renames within: `foundation/hetzner/management`

The pod-role module's naming change (`k8s-mgmt-*` → `k8s-management-*`) means Terraform will destroy+recreate the `hello_world` and `external_secrets` IAM roles during the apply — the Terraform state addresses are unchanged, but the `name` attribute of each `aws_iam_role` changes, which AWS treats as a replacement.

- `hello_world_role`: low risk, no production workloads depend on it.
- `external_secrets_role`: manages secret access for workloads — a brief IAM permissions gap is possible. To mitigate, the pod-role module should set `create_before_destroy = true` on `aws_iam_role.this` so the new role exists before the old one is deleted.

No `state mv` is needed for these — the state addresses stay the same.

### Migration shell script

The script will:
1. `terraform init` all three affected root modules.
2. Pull state files locally via `terraform state pull`.
3. Perform all `state mv` operations with existence checks.
4. Push updated state files via `terraform state push`.
5. Print each operation before executing.

---

## Deployment Order

After migration script is run, apply modules in this order to avoid plan failures:

1. `foundation/hetzner/management` — writes SSM parameters, removes mimir resources
2. `foundation/observability/mimir` — reads SSM parameters, owns mimir resources
3. `foundation/aws/platform` — mimir.tf deleted, no mimir resources remain
