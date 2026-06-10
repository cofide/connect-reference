variable "bundle_domain" {
  type        = string
  description = "Fully qualified domain name for the trust bundle CloudFront distribution (e.g. bundles.connect.example.com)."
}

variable "hosted_zone_id" {
  type        = string
  description = "ID of the Route53 hosted zone in which to create ACM validation and bundle domain alias records."
}

variable "bucket_name" {
  type        = string
  description = "Name of the trust bundle S3 bucket. Used as the CloudFront OAC name and in the bucket policy."
}

variable "bucket_arn" {
  type        = string
  description = "ARN of the trust bundle S3 bucket. Used to scope the CloudFront OAC bucket policy."
}

variable "bucket_regional_domain_name" {
  type        = string
  description = "Regional domain name of the trust bundle S3 bucket. Used as the CloudFront origin domain."
}

variable "bucket_kms_key_arn" {
  type        = string
  description = "ARN of the KMS key used to encrypt the trust bundle bucket. When set, a key policy is created granting the CloudFront distribution kms:Decrypt so it can serve encrypted objects."
  default     = null
}

variable "price_class" {
  type        = string
  description = "CloudFront price class. PriceClass_100 covers US and Europe only (lowest cost); PriceClass_200 adds more regions; PriceClass_All covers all edge locations."

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be one of: PriceClass_100, PriceClass_200, PriceClass_All."
  }
}
