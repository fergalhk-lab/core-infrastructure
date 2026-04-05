variable "cluster_name" {
  description = "Cluster name used to look up OIDC details from SSM — must match a cluster registered via the cluster/ module"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service account. Use \"*\" to match all namespaces (requires role_name to be set)."
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes service account name. Use \"*\" to match all service accounts in the namespace. Partial wildcards are not allowed."
  type        = string
}

variable "policy_document" {
  description = "Optional JSON policy document to attach as an inline policy to the role"
  type        = string
  default     = null
}

variable "role_name" {
  description = "Override for the IAM role name. Required when namespace = \"*\"."
  type        = string
  default     = null

  validation {
    condition     = var.namespace != "*" || var.role_name != null
    error_message = "role_name must be set when namespace = \"*\"."
  }
}
