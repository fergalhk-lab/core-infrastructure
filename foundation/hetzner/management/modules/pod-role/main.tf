locals {
  // Strip the https:// prefix — IAM condition variable keys use the bare hostname
  issuer_host = trimprefix(var.oidc_issuer_url, "https://")
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      // Use StringLike when service_account_name contains a wildcard, StringEquals otherwise
      test     = can(regex("\\*", var.service_account_name)) ? "StringLike" : "StringEquals"
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
