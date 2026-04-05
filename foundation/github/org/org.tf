locals {
  repos = {
    "core-infrastructure" = { private = false, description = null }
    "apps"                = { private = false, description = null }
    "deployer"            = { private = false, description = null }
    "k8s-deployments"     = { private = false, description = "rendered manifests to deploy to Kubernetes" }
  }
}

resource "github_repository" "repos" {
  for_each = local.repos

  name        = each.key
  description = each.value.description
  visibility  = each.value.private ? "private" : "public"

  allow_squash_merge = true
  allow_merge_commit = false
  allow_rebase_merge = false

  delete_branch_on_merge = true
}

resource "random_password" "argocd_webhook_secret" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "argocd_webhook_secret" {
  name = "argocd/webhook-secret"
}

resource "aws_secretsmanager_secret_version" "argocd_webhook_secret" {
  secret_id     = aws_secretsmanager_secret.argocd_webhook_secret.id
  secret_string = random_password.argocd_webhook_secret.result
}

resource "github_repository_webhook" "argocd_k8s_deployments" {
  repository = github_repository.repos["k8s-deployments"].name

  configuration {
    url          = "https://argocd.fergal.website/api/webhook"
    content_type = "application/json"
    secret       = random_password.argocd_webhook_secret.result
    insecure_ssl = false
  }

  active = true
  events = ["push"]
}
