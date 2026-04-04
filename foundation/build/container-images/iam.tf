locals {
  # Flatten to (image_name, github_repo, branches) tuples
  _image_workflow_tuples = flatten([
    for image_name, image_cfg in local.container_images : [
      for wf in image_cfg.github_workflows : {
        image_name  = image_name
        github_repo = wf.repo
        branches    = try(length(wf.branches) > 0 ? wf.branches : null, null)
      }
    ]
  ])

  # Unique set of GitHub repos across all images
  _github_repos = toset([
    for tuple in local._image_workflow_tuples : tuple.github_repo
  ])

  # Per GitHub repo: the ECR repos it may push to, and the trust condition strings
  _github_repo_configs = {
    for github_repo in local._github_repos : github_repo => {
      ecr_repos = toset([
        for tuple in local._image_workflow_tuples : tuple.image_name
        if tuple.github_repo == github_repo
      ])
      branch_conditions = distinct(flatten([
        for tuple in local._image_workflow_tuples :
        tuple.branches == null
        ? ["repo:${tuple.github_repo}:*"]
        : [for branch in tuple.branches : "repo:${tuple.github_repo}:ref:refs/heads/${branch}"]
        if tuple.github_repo == github_repo
      ]))
    }
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
      values   = each.value.branch_conditions
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
      for repo in each.value.ecr_repos :
      "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${repo}"
    ]
  }
}

resource "aws_iam_role_policy" "github_ecr" {
  for_each = local._github_repo_configs
  role     = aws_iam_role.github_ecr[each.key].name
  policy   = data.aws_iam_policy_document.github_ecr[each.key].json
}
