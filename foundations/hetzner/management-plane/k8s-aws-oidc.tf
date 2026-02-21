/*
 * The standard API server endpoint does not have a publicly signed cert, and we
 * can't get one via Cloudflare as it would break mTLS auth.
 *
 * This means that we can't use the standard k8s endpoint to create an OIDC issuer
 * in AWS.
 *
 * To work around this, we:
 *  1. Establish a new "issuer" hostname, given by `local.management_k8s.anonymous_issuer_endpoint`.
 *  2. Create a Kubernetes ingress during host bootstrap, forwarding requests for the OIDC endpoints
 *     to the k8s API server.
 *  3. Create an additional Cloudflare record for the issuer hostname, which is proxied & has a valid
 *     cert, pointing to the ingress.
 *
 */
module "management_k8s_anonymous_issuer_dns" {
  source = "../../../common/tfmodules/cloudflare_record"

  zone_name = local.management_k8s.anonymous_issuer_endpoint.zone
  subdomain = local.management_k8s.anonymous_issuer_endpoint.subdomain
  content   = hcloud_server.management_k8s.ipv4_address
  proxied   = true
}

data "tls_certificate" "management_k8s_oidc" {
  depends_on = [module.management_k8s_anonymous_issuer_dns]
  url        = "tls://${module.management_k8s_anonymous_issuer_dns.fqdn}:443"
}

resource "aws_iam_openid_connect_provider" "management_k8s" {
  url = "https://${module.management_k8s_anonymous_issuer_dns.fqdn}"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [data.tls_certificate.management_k8s_oidc.certificates[0].sha1_fingerprint]
}
