locals {
  issuer_host                 = trimprefix(data.aws_ssm_parameter.oidc_issuer_url.value, "https://")
  cluster_name_short          = data.aws_ssm_parameter.name_short.value
  is_wildcard_service_account = var.service_account_name == "*"
  role_name = local.is_wildcard_service_account ? (
    format("k8s-%s-%s", local.cluster_name_short, var.namespace)
  ) : (
    format("k8s-%s-%s-%s", local.cluster_name_short, var.namespace, var.service_account_name)
  )
}

data "aws_ssm_parameter" "oidc_provider_arn" {
  name = "/k8s/${var.cluster_name}/oidc-provider-arn"
}

data "aws_ssm_parameter" "oidc_issuer_url" {
  name = "/k8s/${var.cluster_name}/oidc-issuer-url"
}

data "aws_ssm_parameter" "name_short" {
  name = "/k8s/${var.cluster_name}/name-short"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_ssm_parameter.oidc_provider_arn.value]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      # only allow wildcard values when matching all service accounts in the namespace
      test     = local.is_wildcard_service_account ? "StringLike" : "StringEquals"
      variable = "${local.issuer_host}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "this" {
  count  = var.policy_document != null ? 1 : 0
  role   = aws_iam_role.this.name
  policy = var.policy_document
}
