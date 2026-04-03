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

data "aws_iam_policy_document" "mimir" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["arn:aws:s3:::fergalhk-mimir/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = ["arn:aws:s3:::fergalhk-mimir"]
  }
}

module "mimir_role" {
  source = "./modules/pod-role"

  oidc_provider_arn    = aws_iam_openid_connect_provider.management_k8s.arn
  oidc_issuer_url      = aws_iam_openid_connect_provider.management_k8s.url
  namespace            = "mimir"
  service_account_name = "mimir"
  policy_document      = data.aws_iam_policy_document.mimir.json
}
