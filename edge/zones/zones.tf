locals {
  // `zones` is a map of FQDN to configuration for all DNS zones.
  zones = {
    "fergal.website" = {}
  }

  zone_defaults = {
    security_level = "medium"
  }
}

module "cloudflare_zones" {
  source   = "./modules/cloudflare_zone"
  for_each = local.zones

  fqdn           = each.key
  security_level = lookup(each.value, "security_level", local.zone_defaults.security_level)
}
