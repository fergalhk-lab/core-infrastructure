data "aws_secretsmanager_secret_version" "cloudflare" {
  count     = var.enable_cloudflare_api_token ? 1 : 0
  secret_id = "apikeys/cloudflare/main"
}

data "aws_secretsmanager_secret_version" "hetzner" {
  for_each  = var.enabled_hetzner_project_api_tokens
  secret_id = "apikeys/hetzner/${each.key}"
}
