output "mimir_role_arn" {
  description = "ARN of the IAM role used by Mimir pods to access S3"
  value       = module.mimir_role.role_arn
}
