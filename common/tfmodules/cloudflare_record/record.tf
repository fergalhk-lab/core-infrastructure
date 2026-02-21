resource "cloudflare_dns_record" "example_dns_record" {
  zone_id = data.cloudflare_zone.name.zone_id
  name    = format("%s.%s", var.subdomain, var.zone_name)
  ttl     = 60
  type    = "A"
  content = var.content
  proxied = true
}
