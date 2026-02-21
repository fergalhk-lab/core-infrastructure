data "aws_secretsmanager_secret_version" "cloudflare" {
  count     = var.enable_cloudflare ? 1 : 0
  secret_id = "apikeys/cloudflare/main"
}

data "aws_secretsmanager_secret_version" "hetzner" {
  for_each  = toset(var.enabled_hetzner_projects)
  secret_id = "apikeys/hetzner/${each.key}"
}
