locals {
  auth_aws_account = "platform"
}

provider "aws" {
  assume_role {
    role_arn = module.meta.aws_deploy_role_arns[local.auth_aws_account]
  }
}
