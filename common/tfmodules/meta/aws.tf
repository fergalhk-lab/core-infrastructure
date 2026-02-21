locals {
  aws_data = yamldecode(file(format("%s/../../../config/aws.yaml", path.module)))
  aws_account_ids = {
    for acct, cfg in local.aws_data.accounts : acct => cfg.id
  }
  aws_deploy_role_name = "terraform"
  aws_deploy_role_arns = {
    for acct, id in local.aws_account_ids : acct => format("arn:aws:iam::%s:role/%s", id, local.aws_deploy_role_name)
  }
}
