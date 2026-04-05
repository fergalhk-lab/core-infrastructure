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
