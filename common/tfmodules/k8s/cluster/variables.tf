variable "cluster_name" {
  description = "SSM path key for this cluster (e.g. \"management\")"
  type        = string
}

variable "cluster_name_short" {
  description = "Short cluster name stored in SSM and used in IAM role names (e.g. \"mgmt\")"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the aws_iam_openid_connect_provider for this cluster"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL for this cluster"
  type        = string
}
