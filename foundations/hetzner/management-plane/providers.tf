locals {
  // TODO - update this
  hetzner_project = "build"
}

provider "cloudflare" {
  api_token = module.meta.cloudflare_api_key
}

provider "hcloud" {
  token = module.meta.hetzner_keys[local.hetzner_project]
}
