# GitHub Org Terraform Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Terraform root module at `foundation/github/org` that manages the `fergalhk-lab` GitHub org via IaC, authenticated using a GitHub App whose credentials are stored in AWS Secrets Manager.

**Architecture:** The existing `authmeta` child module is extended to optionally fetch GitHub App credentials from a single Secrets Manager secret (`apikeys/github/terraform-core-infrastructure`). A new root module (`foundation/github/org`) calls `authmeta` with `enable_github = true`, uses the resulting outputs to configure the `integrations/github` provider, and is registered in the pipeline via `config/terraform.yaml`. The GitHub App and its Secrets Manager secret must be created manually before the first pipeline run (see bootstrap steps below).

**Tech Stack:** Terraform >= 1.3.0, `integrations/github` ~> 6.0, `hashicorp/aws` ~> 5.0, AWS Secrets Manager, GitHub App auth.

---

## Bootstrap (manual, one-time — do this before Task 3)

1. In `fergalhk-lab` org: **Settings → Developer settings → GitHub Apps → New GitHub App**
   - Set **Organisation permissions**: Members (write), Administration (write)
   - Set **Repository permissions**: Administration (write), Contents (write), Metadata (read)
   - Disable webhooks
   - Save. Note the **App ID** shown on the App settings page.
   - Generate a private key (button at bottom of App settings page). Save the downloaded `.pem` file.
   - Install the App on the org: **Install App → fergalhk-lab → All repositories**. After install, note the **installation ID** — it is the trailing number in the URL (e.g. `https://github.com/organizations/fergalhk-lab/settings/installations/12345678`).

2. In AWS Secrets Manager (`eu-west-1`, platform account), create a secret named `apikeys/github/terraform-core-infrastructure` with this JSON value:
   ```json
   {
     "app_id": "<App ID from step 1>",
     "installation_id": "<Installation ID from step 1>",
     "private_key": "<full contents of the .pem file, including header/footer lines>"
   }
   ```

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| Modify | `common/tfmodules/authmeta/variables.tf` | Add `enable_github` variable |
| Modify | `common/tfmodules/authmeta/main.tf` | Add GitHub secret data source and decoded local |
| Modify | `common/tfmodules/authmeta/outputs.tf` | Add three GitHub outputs |
| Create | `foundation/github/org/versions.tf` | Provider version constraints |
| Create | `foundation/github/org/meta.tf` | `module "meta"` call |
| Create | `foundation/github/org/providers.tf` | `module "authmeta"` + AWS + GitHub provider configs |
| Create | `foundation/github/org/org.tf` | Empty file — GitHub resources live here |
| Modify | `config/terraform.yaml` | Register module in pipeline |

---

## Task 1: Extend `authmeta` — add GitHub variable and data source

**Files:**
- Modify: `common/tfmodules/authmeta/variables.tf`
- Modify: `common/tfmodules/authmeta/main.tf`

- [ ] **Step 1: Add `enable_github` variable**

  Append to `common/tfmodules/authmeta/variables.tf`:
  ```hcl
  variable "enable_github" {
    type    = bool
    default = false
  }
  ```

  Full file after change:
  ```hcl
  variable "enable_cloudflare" {
    type    = bool
    default = false
  }

  variable "enabled_hetzner_projects" {
    type    = set(string)
    default = []
  }

  variable "enable_github" {
    type    = bool
    default = false
  }
  ```

- [ ] **Step 2: Add GitHub secret data source and decoded local to `main.tf`**

  Full file after change (`common/tfmodules/authmeta/main.tf`):
  ```hcl
  module "meta" {
    source = "../meta"
  }

  data "aws_secretsmanager_secret_version" "cloudflare" {
    count     = var.enable_cloudflare ? 1 : 0
    secret_id = "apikeys/cloudflare/main"
  }

  data "aws_secretsmanager_secret_version" "hetzner" {
    for_each  = var.enabled_hetzner_projects
    secret_id = "apikeys/hetzner/${each.key}"
  }

  data "aws_secretsmanager_secret_version" "github" {
    count     = var.enable_github ? 1 : 0
    secret_id = "apikeys/github/terraform-core-infrastructure"
  }

  locals {
    github_secret = var.enable_github ? jsondecode(data.aws_secretsmanager_secret_version.github[0].secret_string) : {}
  }
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add common/tfmodules/authmeta/variables.tf common/tfmodules/authmeta/main.tf
  git commit -m "feat(authmeta): add GitHub App credentials support"
  ```

---

## Task 2: Extend `authmeta` — add GitHub outputs

**Files:**
- Modify: `common/tfmodules/authmeta/outputs.tf`

- [ ] **Step 1: Add three GitHub outputs**

  Full file after change (`common/tfmodules/authmeta/outputs.tf`):
  ```hcl
  output "cloudflare_api_key" {
    value     = var.enable_cloudflare ? data.aws_secretsmanager_secret_version.cloudflare[0].secret_string : null
    sensitive = true
  }

  output "hetzner_keys" {
    value     = { for project, secret in data.aws_secretsmanager_secret_version.hetzner : project => secret.secret_string }
    sensitive = true
  }

  output "github_app_id" {
    value     = var.enable_github ? lookup(local.github_secret, "app_id", null) : null
    sensitive = true
  }

  output "github_app_installation_id" {
    value     = var.enable_github ? lookup(local.github_secret, "installation_id", null) : null
    sensitive = true
  }

  output "github_app_private_key" {
    value     = var.enable_github ? lookup(local.github_secret, "private_key", null) : null
    sensitive = true
  }
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add common/tfmodules/authmeta/outputs.tf
  git commit -m "feat(authmeta): add GitHub App credential outputs"
  ```

---

## Task 3: Create `foundation/github/org` root module

**Files:**
- Create: `foundation/github/org/versions.tf`
- Create: `foundation/github/org/meta.tf`
- Create: `foundation/github/org/providers.tf`
- Create: `foundation/github/org/org.tf`

- [ ] **Step 1: Create `versions.tf`**

  ```hcl
  terraform {
    required_version = ">= 1.3.0"

    required_providers {
      github = {
        source  = "integrations/github"
        version = "~> 6.0"
      }
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
      }
    }
  }
  ```

- [ ] **Step 2: Create `meta.tf`**

  ```hcl
  module "meta" {
    source = "../../../common/tfmodules/meta"
  }
  ```

- [ ] **Step 3: Create `providers.tf`**

  ```hcl
  module "authmeta" {
    source        = "../../../common/tfmodules/authmeta"
    enable_github = true
  }

  provider "aws" {
    assume_role {
      role_arn = module.meta.aws_deploy_role_arns["platform"]
    }
  }

  provider "github" {
    owner = "fergalhk-lab"

    app_auth {
      id              = module.authmeta.github_app_id
      installation_id = module.authmeta.github_app_installation_id
      pem_file        = module.authmeta.github_app_private_key
    }
  }
  ```

- [ ] **Step 4: Create `org.tf`**

  ```hcl
  # GitHub org resources — add repositories, teams, memberships, and app installations here.
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add foundation/github/org/
  git commit -m "feat: add foundation/github/org terraform root module"
  ```

---

## Task 4: Register module in pipeline

**Files:**
- Modify: `config/terraform.yaml`

- [ ] **Step 1: Add module to `config/terraform.yaml`**

  Full file after change:
  ```yaml
  modules:
    - foundation/terraform-state-backend
    - foundation/aws/platform
    - edge/zones
    - foundation/hetzner/management
    - foundation/build/container-images
    - foundation/github/org
  ```

- [ ] **Step 2: Commit and push**

  ```bash
  git add config/terraform.yaml
  git commit -m "feat: register foundation/github/org in terraform pipeline"
  git push
  ```

  This triggers the pipeline. On the first run, the plan should show no changes (empty `org.tf`). The apply confirms auth is working end-to-end. If the plan fails with an auth error, verify the Secrets Manager secret exists and contains all three fields (`app_id`, `installation_id`, `private_key`).
