output "cloudflare_account_id" {
  value = local.cloudflare_account_id
}

output "ssh_public_keys" {
  value = local.ssh_public_keys
}

output "aws_account_ids" {
  value = local.aws_account_ids
}

output "aws_deploy_role_arns" {
  value = local.aws_deploy_role_arns
}

output "cloudflare_api_key" {
  value     = var.enable_cloudflare_api_token ? data.aws_secretsmanager_secret_version.cloudflare[0].secret_string : null
  sensitive = true
}

output "hetzner_keys" {
  value     = { for project, secret in data.aws_secretsmanager_secret_version.hetzner : project => secret.secret_string }
  sensitive = true
}
