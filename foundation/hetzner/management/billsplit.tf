module "billsplit_role" {
  source = "./modules/pod-role"

  oidc_provider_arn    = aws_iam_openid_connect_provider.management_k8s.arn
  oidc_issuer_url      = aws_iam_openid_connect_provider.management_k8s.url
  namespace            = "billsplit"
  service_account_name = "*"
}

resource "aws_s3_bucket" "billsplit_live" {
  bucket = "fergalhk-billsplit-live"
}

resource "aws_s3_bucket_public_access_block" "billsplit_live" {
  bucket = aws_s3_bucket.billsplit_live.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
