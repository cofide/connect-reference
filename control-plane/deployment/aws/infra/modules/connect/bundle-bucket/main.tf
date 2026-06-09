/**
 * # connect/bundle-bucket
 *
 * Creates a KMS-encrypted S3 bucket for storing SPIFFE trust bundles written by the
 * Connect API. Versioning is enabled and public access is blocked. Write access for
 * the Connect API is granted separately via the `connect/iam-role` module.
 */

resource "aws_kms_key" "bundle_bucket" {
  description             = "KMS key for Connect trust bundle S3 bucket"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_key_deletion_window_in_days
}

resource "aws_kms_alias" "bundle_bucket" {
  name          = var.kms_key_alias
  target_key_id = aws_kms_key.bundle_bucket.key_id
}

resource "aws_s3_bucket" "bundle" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "bundle" {
  bucket = aws_s3_bucket.bundle.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bundle" {
  bucket = aws_s3_bucket.bundle.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.bundle_bucket.arn
    }
    # Bucket keys reduce the number of KMS API calls (and therefore cost) by
    # generating a short-lived data key per bucket rather than per object.
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "bundle" {
  bucket                  = aws_s3_bucket.bundle.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
