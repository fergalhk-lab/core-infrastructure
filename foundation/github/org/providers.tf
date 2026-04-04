module "authmeta" {
  source        = "../../../common/tfmodules/authmeta"
  enable_github = true
}

provider "aws" {
  assume_role {
    role_arn = module.meta.aws_deploy_role_arns["platform"]
  }
}

provider "github" {
  owner = "fergalhk-lab"

  app_auth {
    id              = module.authmeta.github_app_id
    installation_id = module.authmeta.github_app_installation_id
    pem_file        = module.authmeta.github_app_private_key
  }
}
