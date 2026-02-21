locals {
  aws_account = "platform"
}

provider "aws" {
  alias = "bootstrap"
}

provider "aws" {
  assume_role {
    role_arn = local.aws_deploy_role_arns[local.aws_account]
  }
}
