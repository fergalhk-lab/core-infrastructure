locals {
  repos = {
    "core-infrastructure" = { private = true }
    "apps"                = { private = false }
    "deployer"            = { private = false }
  }
}

resource "github_repository" "repos" {
  for_each = local.repos

  name       = each.key
  visibility = each.value.private ? "private" : "public"

  allow_squash_merge = true
  allow_merge_commit = false
  allow_rebase_merge = false

  delete_branch_on_merge = true
}
