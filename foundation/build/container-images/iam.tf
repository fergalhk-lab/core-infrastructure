locals {
  # Flatten to (image_name, github_repo, branches) tuples
  _image_workflow_tuples = flatten([
    for image_name, image_cfg in local.container_images : [
      for wf in image_cfg.github_workflows : {
        image_name  = image_name
        github_repo = wf.repo
        branches    = try(wf.branches, null)
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
