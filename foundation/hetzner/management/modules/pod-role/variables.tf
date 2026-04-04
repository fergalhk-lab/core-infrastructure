locals {
  role_name                   = local.is_wildcard_service_account ? format("k8s-mgmt-%s", var.namespace) : format("k8s-mgmt-%s-%s", var.namespace, var.service_account_name)
  is_wildcard_service_account = var.service_account_name == "*"
}

variable "oidc_provider_arn" {
  description = "ARN of the AWS IAM OIDC provider for the management K8s cluster"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL for the management K8s cluster (with https:// prefix)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service account"
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes service account name. Use special value `*` to match all service accounts in the namespace. Note that partial wildcards are not allowed."
  type        = string
}

variable "policy_document" {
  description = "Optional JSON policy document to attach as an inline policy to the role"
  type        = string
  default     = null
}
