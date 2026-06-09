variable "role_name" {
  type        = string
  description = "Name of the IAM role for the Connect API."
}

variable "spire_oidc_domain" {
  type        = string
  description = "Full domain of the SPIRE server OIDC discovery endpoint (e.g. oidc.connect.example.com). Used to register the IAM OIDC provider and construct trust policy conditions."
}

variable "spiffe_id" {
  type        = string
  description = "SPIFFE ID of the Connect API workload (e.g. spiffe://trust-domain/ns/connect/sa/connect-api). Used as the sub condition in the IAM role trust policy to restrict JWT SVID exchange to this specific workload identity."
}

variable "bundle_bucket_arn" {
  type        = string
  default     = null
  description = "ARN of the trust bundle S3 bucket. When set, grants s3:PutObject, s3:PutObjectTagging, s3:DeleteObject, and s3:ListBucket. When null, no S3 policy is attached."
}

variable "bundle_bucket_kms_key_arn" {
  type        = string
  default     = null
  description = "ARN of the KMS key used to encrypt the trust bundle bucket. When set, grants kms:GenerateDataKey. Required alongside bundle_bucket_arn when the bucket uses SSE-KMS."
}

variable "db_resource_id" {
  type        = string
  default     = null
  description = "RDS DbiResourceId for the Connect API database instance. When set alongside db_username, grants rds-db:connect for IAM authentication. When null, no RDS policy is attached."
}

variable "db_username" {
  type        = string
  default     = null
  description = "PostgreSQL role name for the Connect API. Used to construct the rds-db:connect IAM resource ARN."
}
