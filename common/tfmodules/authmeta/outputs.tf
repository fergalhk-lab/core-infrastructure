output "cloudflare_api_key" {
  value     = var.enable_cloudflare ? data.aws_secretsmanager_secret_version.cloudflare[0].secret_string : null
  sensitive = true
}

output "hetzner_keys" {
  value     = { for project, secret in data.aws_secretsmanager_secret_version.hetzner : project => secret.secret_string }
  sensitive = true
}

output "github_app_id" {
  value     = var.enable_github ? lookup(local.github_secret, "app_id", null) : null
  sensitive = true
}

output "github_app_installation_id" {
  value     = var.enable_github ? lookup(local.github_secret, "installation_id", null) : null
  sensitive = true
}

output "github_app_private_key" {
  value     = var.enable_github ? lookup(local.github_secret, "private_key", null) : null
  sensitive = true
}
