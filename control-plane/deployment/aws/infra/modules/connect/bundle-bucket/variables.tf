variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket for trust bundles. Must be globally unique."
}

variable "kms_key_alias" {
  type        = string
  description = "Alias for the KMS key used to encrypt the trust bundle bucket. Must begin with 'alias/'."

  validation {
    condition     = startswith(var.kms_key_alias, "alias/")
    error_message = "kms_key_alias must begin with 'alias/'."
  }
}

variable "kms_key_deletion_window_in_days" {
  type        = number
  description = "Number of days to wait before deleting the KMS key after it is scheduled for deletion. Valid range is 7–30."

  validation {
    condition     = var.kms_key_deletion_window_in_days >= 7 && var.kms_key_deletion_window_in_days <= 30
    error_message = "kms_key_deletion_window_in_days must be between 7 and 30."
  }
}

variable "force_destroy" {
  type        = bool
  description = "Boolean which indicates whether all objects should be deleted from the bucket when the bucket is destroyed."
}
