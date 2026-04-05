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

module "hello_world_role" {
  source = "../../../../common/tfmodules/k8s/pod-role"

  cluster_name         = "management"
  namespace            = "hello-world"
  service_account_name = "fergal"
}

module "external_secrets_role" {
  source = "../../../../common/tfmodules/k8s/pod-role"

  cluster_name         = "management"
  namespace            = "external-secrets"
  service_account_name = "external-secrets"
  policy_document      = data.aws_iam_policy_document.external_secrets.json
}
