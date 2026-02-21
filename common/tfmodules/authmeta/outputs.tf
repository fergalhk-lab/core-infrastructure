output "cloudflare_api_key" {
  value     = var.enable_cloudflare ? data.aws_secretsmanager_secret_version.cloudflare[0].secret_string : null
  sensitive = true
}

output "hetzner_keys" {
  value     = { for project, secret in data.aws_secretsmanager_secret_version.hetzner : project => secret.secret_string }
  sensitive = true
}
