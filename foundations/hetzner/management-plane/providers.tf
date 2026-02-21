locals {
  hetzner_project = "management"

  // aws account the cluster is authorized to assume roles in
  auth_aws_account = "platform"
}

module "authmeta" {
  source                   = "../../../common/tfmodules/authmeta"
  enable_cloudflare        = true
  enabled_hetzner_projects = [local.hetzner_project]
}

provider "cloudflare" {
  api_token = module.authmeta.cloudflare_api_key
}

provider "hcloud" {
  token = module.authmeta.hetzner_keys[local.hetzner_project]
}

provider "aws" {
  assume_role {
    role_arn = module.meta.aws_deploy_role_arns[local.auth_aws_account]
  }
}
