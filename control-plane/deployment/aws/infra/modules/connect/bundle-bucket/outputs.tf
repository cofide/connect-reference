output "bucket_name" {
  description = "Name of the trust bundle S3 bucket."
  value       = aws_s3_bucket.bundle.id
}

output "bucket_arn" {
  description = "ARN of the trust bundle S3 bucket."
  value       = aws_s3_bucket.bundle.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the trust bundle S3 bucket. Used as the CloudFront origin domain."
  value       = aws_s3_bucket.bundle.bucket_regional_domain_name
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the trust bundle bucket."
  value       = aws_kms_key.bundle_bucket.arn
}
