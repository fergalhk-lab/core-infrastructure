locals {
  aws_account = "platform"
}

module "meta" {
  source = "../meta"
}

provider "aws" {
  alias = "bootstrap"
}

provider "aws" {
  assume_role {
    role_arn = module.meta.aws_deploy_role_arns[local.aws_account]
  }
}
