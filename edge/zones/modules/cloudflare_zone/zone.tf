locals {
  zone_settings = {
    security_level = var.security_level
    ssl            = var.ssl_mode
  }

  cloudflare_account_id = module.meta.cloudflare_account_id
}

resource "cloudflare_zone" "this" {
  account = {
    id = local.cloudflare_account_id
  }
  name = var.fqdn
  type = "full"
}

resource "cloudflare_zone_setting" "this" {
  for_each   = local.zone_settings
  zone_id    = cloudflare_zone.this.id
  setting_id = each.key
  value      = each.value
}
