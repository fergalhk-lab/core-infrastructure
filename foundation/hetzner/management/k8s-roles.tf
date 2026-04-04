module "hello_world_role" {
  source = "./modules/pod-role"

  oidc_provider_arn    = aws_iam_openid_connect_provider.management_k8s.arn
  oidc_issuer_url      = aws_iam_openid_connect_provider.management_k8s.url
  namespace            = "hello-world"
  service_account_name = "fergal"
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = ["*"]
  }
}

module "external_secrets_role" {
  source = "./modules/pod-role"

  oidc_provider_arn    = aws_iam_openid_connect_provider.management_k8s.arn
  oidc_issuer_url      = aws_iam_openid_connect_provider.management_k8s.url
  namespace            = "external-secrets"
  service_account_name = "external-secrets"
  policy_document      = data.aws_iam_policy_document.external_secrets.json
}

locals {
  management_k8s_oidc_issuer_host = trimprefix(aws_iam_openid_connect_provider.management_k8s.url, "https://")
}

data "aws_iam_policy_document" "ecr_pull_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.management_k8s.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.management_k8s_oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # The kubelet credential provider generates tokens on behalf of any pod,
    # so we cannot scope this to a specific service account.
    condition {
      test     = "StringLike"
      variable = "${local.management_k8s_oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:*:*"]
    }
  }
}

data "aws_iam_policy_document" "ecr_pull" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = ["arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/*"]
  }
}

resource "aws_iam_role" "ecr_pull" {
  name               = "k8s-management-ecr-pull"
  assume_role_policy = data.aws_iam_policy_document.ecr_pull_assume_role.json
}

resource "aws_iam_role_policy" "ecr_pull" {
  role   = aws_iam_role.ecr_pull.name
  policy = data.aws_iam_policy_document.ecr_pull.json
}
