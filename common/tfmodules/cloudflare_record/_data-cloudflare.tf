data "cloudflare_zone" "this" {
  filter = {
    match = "all"
    name  = var.zone_name
  }
}
