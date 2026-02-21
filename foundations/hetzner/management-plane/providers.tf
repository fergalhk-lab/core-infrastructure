locals {
  // TODO - update this
  hetzner_project = "build"
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
