module "hello_world_role" {
  source = "./modules/pod-role"

  oidc_provider_arn    = aws_iam_openid_connect_provider.management_k8s.arn
  oidc_issuer_url      = aws_iam_openid_connect_provider.management_k8s.url
  namespace            = "hello-world"
  service_account_name = "fergal"
}
