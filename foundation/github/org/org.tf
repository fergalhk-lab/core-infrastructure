locals {
  repos = {
    "core-infrastructure" = {
      private      = false
      description  = "foundational infrastructure"
      environments = {
        "terraform-apply" = { reviewer_usernames = ["fhke"] }
      }
    }
    "apps" = {
      private      = false
      description  = "monorepo for apps"
      environments = {}
    }
    "deployer" = {
      private      = false
      description  = "simple deployment tool"
      environments = {}
    }
    "k8s-deployments" = {
      private      = false
      description  = "rendered manifests to deploy to Kubernetes"
      environments = {}
    }
  }

  repo_environments = {
    for pair in flatten([
      for repo_name, repo in local.repos : [
        for env_name, env in repo.environments : {
          key                = "${repo_name}/${env_name}"
          repo_name          = repo_name
          env_name           = env_name
          reviewer_usernames = env.reviewer_usernames
        }
      ]
    ]) : pair.key => pair
  }

  all_reviewer_usernames = toset(flatten([
    for env in values(local.repo_environments) : env.reviewer_usernames
  ]))
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

data "github_user" "reviewers" {
  for_each = local.all_reviewer_usernames
  username = each.key
}

resource "github_repository_environment" "environments" {
  for_each = local.repo_environments

  repository  = github_repository.repos[each.value.repo_name].name
  environment = each.value.env_name

  reviewers {
    users = [for u in each.value.reviewer_usernames : data.github_user.reviewers[u].id]
  }
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
