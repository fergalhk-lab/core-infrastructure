module "authmeta" {
  source            = "../../common/tfmodules/authmeta"
  enable_cloudflare = true
}

provider "cloudflare" {
  api_token = module.authmeta.cloudflare_api_key
}
