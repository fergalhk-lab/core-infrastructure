locals {
  repos = {
    "core-infrastructure" = { private = true, description = null }
    "apps"                = { private = true, description = null }
    "deployer"            = { private = true, description = null }
    "k8s-deployments"     = { private = true, description = "rendered manifests to deploy to Kubernetes" }
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
