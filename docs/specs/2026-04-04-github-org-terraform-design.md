# GitHub Org Terraform Module — Design Spec

**Date:** 2026-04-04
**Org:** `fergalhk-lab`

## Overview

Add a Terraform root module to manage the `fergalhk-lab` GitHub org via IaC. Covers repositories, teams, memberships, and GitHub App installations. Auth is via a GitHub App installed on the org, with credentials stored in AWS Secrets Manager and retrieved at plan/apply time via the existing `authmeta` module pattern.

---

## Section 1: Auth Wiring

### GitHub App

A GitHub App is created once manually in the `fergalhk-lab` org with the following permissions:

**Organisation permissions:**
- Members: write
- Administration: write

**Repository permissions:**
- Administration: write
- Contents: write
- Metadata: read (required)

The App is installed on the org (all repositories). The App ID and PEM private key are stored together in a single AWS Secrets Manager secret.

### Secrets Manager

Secret name: `apikeys/github/terraform-core-infrastructure`
AWS account: platform
Region: `eu-west-1`

Secret value (JSON):
```json
{
  "app_id": "<GitHub App ID>",
  "installation_id": "<GitHub App Installation ID>",
  "private_key": "-----BEGIN RSA PRIVATE KEY-----\n..."
}
```

The installation ID is found on the App's installation page in the org (Settings → Installed GitHub Apps → Configure → the numeric ID in the URL).

### `authmeta` module changes

- New input variable: `enable_github` (bool, default `false`)
- When `true`: reads `apikeys/github/terraform-core-infrastructure` from Secrets Manager, decodes JSON with `jsondecode`, extracts fields with `lookup()`
- New outputs: `github_app_id` (string, sensitive), `github_app_installation_id` (string, sensitive), `github_app_private_key` (string, sensitive)

---

## Section 2: Module Structure

New root module at `foundation/github/org/`:

```
foundation/github/org/
├── versions.tf      # required_providers: integrations/github
├── providers.tf     # github provider configured with App credentials
├── meta.tf          # module "meta" and module "authmeta" (enable_github = true)
└── org.tf           # GitHub resources — starts empty, populated as resources are added
```

**`providers.tf`** configures the `integrations/github` provider using an `app_auth` block with:
- `id` from `module.authmeta.github_app_id`
- `installation_id` from `module.authmeta.github_app_installation_id`
- `pem_file` from `module.authmeta.github_app_private_key`
- `owner = "fergalhk-lab"` (top-level provider argument)

**State:** stored in S3 at `core-infrastructure/foundation/github/org/terraform.tfstate`, auto-derived by `util/terraform.sh` from the module path.

**Pipeline:** `foundation/github/org` is added to `config/terraform.yaml` so the existing GitHub Actions workflow picks it up automatically.

---

## Section 3: Bootstrap Process (one-time manual steps)

These steps must be completed before the pipeline can run against this module.

1. **Create the GitHub App** in `fergalhk-lab` org settings (Settings → Developer settings → GitHub Apps → New GitHub App):
   - Set the permissions listed in Section 1
   - Disable webhooks (not needed)
   - Install the App on the org (all repositories)
   - Note the App ID from the App's settings page
   - Generate a private key (downloads a `.pem` file)
   - Note the installation ID from the installation URL (Settings → Installed GitHub Apps → Configure — the numeric ID at the end of the URL)

2. **Store credentials in Secrets Manager** — create secret `apikeys/github/terraform-core-infrastructure` in the platform AWS account (`eu-west-1`) with the JSON structure shown in Section 1 (all three fields: `app_id`, `installation_id`, `private_key`).

3. **First pipeline run** — add `foundation/github/org` to `config/terraform.yaml` and push. The pipeline will plan/apply the empty module, confirming auth is working. Resources can then be added to `org.tf`.

---

## Out of Scope

- Creating the GitHub App itself via Terraform (requires pre-existing credentials to bootstrap)
- Managing GitHub Actions secrets or environments (separate concern)
