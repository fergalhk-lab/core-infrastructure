locals {
  github_repo = "fergalhk-lab/core-infrastructure"
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint list is required by the API but AWS ignores it for
  # token.actions.githubusercontent.com and validates against its own trust store.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_core_infrastructure_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_core_infrastructure" {
  name               = "github-core-infrastructure"
  assume_role_policy = data.aws_iam_policy_document.github_core_infrastructure_assume_role.json
}

data "aws_iam_policy_document" "github_core_infrastructure" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = formatlist("arn:aws:iam::%s:role/terraform", values(module.meta.aws_account_ids))
  }

  statement {
    sid    = "ListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
    ]
    resources = [data.aws_s3_bucket.terraform_states.arn]
  }

  statement {
    sid    = "ReadWriteObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [format("%s/*", data.aws_s3_bucket.terraform_states.arn)]
  }

  statement {
    sid     = "GetAPIKeys"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      format("arn:aws:secretsmanager:*:%s:secret:apikeys/*", data.aws_caller_identity.current.account_id)
    ]
  }
}

resource "aws_iam_role_policy" "github_core_infrastructure" {
  role   = aws_iam_role.github_core_infrastructure.name
  policy = data.aws_iam_policy_document.github_core_infrastructure.json
}
