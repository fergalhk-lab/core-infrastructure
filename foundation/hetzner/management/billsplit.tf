# TODO: extract billsplit resources into their own Terraform module

module "billsplit_role" {
  source = "../../../common/tfmodules/k8s/pod-role"

  cluster_name         = "management"
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

resource "aws_iam_role_policy" "billsplit_s3" {
  name = "billsplit-s3"
  role = module.billsplit_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          "${aws_s3_bucket.billsplit_live.arn}/*",
          aws_s3_bucket.billsplit_live.arn,
        ]
      }
    ]
  })
}
