locals {
  # Flatten to (image_name, github_repo) tuples
  _image_workflow_tuples = flatten([
    for image_name, image_cfg in local.container_images : [
      for wf in image_cfg.github_workflows : {
        image_name  = image_name
        github_repo = wf.repo
      }
    ]
  ])

  # Per GitHub repo: the set of ECR repo names it may push to
  _github_repo_configs = {
    for github_repo in toset([for t in local._image_workflow_tuples : t.github_repo]) :
    github_repo => toset([
      for t in local._image_workflow_tuples : t.image_name
      if t.github_repo == github_repo
    ])
  }
}

data "aws_iam_policy_document" "github_ecr_assume_role" {
  for_each = local._github_repo_configs

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${each.key}:*"]
    }
  }
}

resource "aws_iam_role" "github_ecr" {
  for_each           = local._github_repo_configs
  name               = "gh-ecr-${replace(each.key, "/", "-")}"
  assume_role_policy = data.aws_iam_policy_document.github_ecr_assume_role[each.key].json
}

data "aws_iam_policy_document" "github_ecr" {
  for_each = local._github_repo_configs

  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [
      for repo in each.value :
      "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${repo}"
    ]
  }
}

resource "aws_iam_role_policy" "github_ecr" {
  for_each = local._github_repo_configs
  role     = aws_iam_role.github_ecr[each.key].name
  policy   = data.aws_iam_policy_document.github_ecr[each.key].json
}
