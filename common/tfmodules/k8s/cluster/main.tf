resource "aws_ssm_parameter" "oidc_provider_arn" {
  name  = "/k8s/${var.cluster_name}/oidc-provider-arn"
  type  = "String"
  value = var.oidc_provider_arn
}

resource "aws_ssm_parameter" "oidc_issuer_url" {
  name  = "/k8s/${var.cluster_name}/oidc-issuer-url"
  type  = "String"
  value = var.oidc_issuer_url
}

resource "aws_ssm_parameter" "name_short" {
  name  = "/k8s/${var.cluster_name}/name-short"
  type  = "String"
  value = var.cluster_name_short
}
