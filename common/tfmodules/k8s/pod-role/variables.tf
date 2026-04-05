variable "cluster_name" {
  description = "Cluster name used to look up OIDC details from SSM — must match a cluster registered via the cluster/ module"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service account"
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
