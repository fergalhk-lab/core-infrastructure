locals {
  # Derived from the static local rather than the resource to avoid a dependency
  # cycle through hcloud_server.management_k8s (which references aws_iam_role.ecr_pull).
  management_k8s_oidc_issuer_host = "${local.management_k8s.anonymous_issuer_endpoint.subdomain}.${local.management_k8s.anonymous_issuer_endpoint.zone}"
}

data "aws_iam_policy_document" "ecr_pull_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      # Construct ARN directly to avoid a cycle through hcloud_server.management_k8s.
      # aws_iam_openid_connect_provider.management_k8s depends on data.tls_certificate
      # which depends on the server IP, but the server user_data references this role.
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.management_k8s_oidc_issuer_host}"]
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
