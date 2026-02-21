locals {
  bucket_name = "fergalhk-terraform-state"

  github_org  = "fergalhk-lab"
  github_repo = "core-infrastructure"

  oidc_provider_url = "https://token.actions.githubusercontent.com"

}
