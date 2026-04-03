# Mimir block storage bucket.
#
# Tradeoff: single bucket for all Mimir data (blocks, ruler, alertmanager).
# For higher isolation or cross-region replication, separate buckets per subsystem
# could be used — see https://grafana.com/docs/mimir/latest/configure/configure-object-storage-backend/
resource "aws_s3_bucket" "mimir" {
  bucket = "fergalhk-mimir"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mimir" {
  bucket = aws_s3_bucket.mimir.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "mimir" {
  bucket = aws_s3_bucket.mimir.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
