module "meta" {
  source = "../../../common/tfmodules/meta"

  enable_cloudflare_api_token        = true
  enabled_hetzner_project_api_tokens = [local.hetzner_project]
}
