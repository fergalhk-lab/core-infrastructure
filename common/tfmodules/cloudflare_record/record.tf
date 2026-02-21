resource "cloudflare_dns_record" "this" {
  zone_id = data.cloudflare_zone.this.zone_id
  name    = format("%s.%s", var.subdomain, var.zone_name)
  ttl     = 60
  type    = "A"
  content = var.content
  proxied = true
}
