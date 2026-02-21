locals {
  aws_account = "platform"
}

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws, aws.bootstrap]
    }
  }
}

module "meta" {
  source = "../../../common/tfmodules/meta"
}

provider "aws" {
  alias = "bootstrap"
}

provider "aws" {
  assume_role {
    role_arn     = module.meta.aws_deploy_role_arns[local.aws_account]
    session_name = "gha"
  }
}
