locals {
  zone_settings = {
    security_level = var.security_level
  }

  cloudflare_account_id = "9072364b7171093a15896dd5e86613a6"
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
