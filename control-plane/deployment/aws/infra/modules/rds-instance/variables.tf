variable "ingress_security_groups" {
  type = map(object({
    security_group_id = string
    description       = string
  }))
  description = "Security groups permitted to connect to the RDS instance on port 5432. Map key is used as the Terraform resource key."
  default     = {}
}

variable "vpc_id" {
  type        = string
  description = "VPC ID in which to create the RDS security group."
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the RDS subnet group."
}

variable "db_identifier" {
  type        = string
  description = "RDS DB instance identifier."
}

variable "subnet_group_name" {
  type        = string
  description = "Name for the RDS DB subnet group."
}

variable "parameter_group_name" {
  type        = string
  description = "Name for the RDS DB parameter group."
}

variable "security_group_name" {
  type        = string
  description = "Name for the RDS security group."
}

variable "db_username" {
  type        = string
  default     = "postgres"
  description = "Master username for the RDS instance."
}

variable "db_instance_class" {
  type        = string
  default     = "db.t3.medium"
  description = "RDS instance class."
}

variable "postgres_version" {
  type        = string
  default     = "17"
  description = "PostgreSQL engine version."
}

variable "kms_key_alias" {
  type        = string
  description = "Alias for the KMS key used for RDS storage encryption. Must begin with 'alias/'."

  validation {
    condition     = startswith(var.kms_key_alias, "alias/")
    error_message = "kms_key_alias must begin with 'alias/'."
  }
}

variable "secret_kms_key_alias" {
  type        = string
  description = "Alias for the KMS key used to encrypt the RDS master user secret in Secrets Manager. Must begin with 'alias/'."

  validation {
    condition     = startswith(var.secret_kms_key_alias, "alias/")
    error_message = "secret_kms_key_alias must begin with 'alias/'."
  }
}

variable "storage_type" {
  type        = string
  default     = "gp3"
  description = "Storage type for the RDS instance. gp3 provides better price/performance than gp2."
}

variable "allocated_storage" {
  type        = number
  default     = 20
  description = "Initial allocated storage in GiB."
}

variable "max_allocated_storage" {
  type        = number
  default     = 100
  description = "Maximum storage in GiB for autoscaling. Must be greater than allocated_storage. Production deployments should set a higher ceiling."
}

variable "backup_retention_period" {
  type        = number
  default     = 1
  description = "Number of days to retain automated backups. Minimum 1 to keep backups enabled. Production deployments should set 7 or higher."
}

variable "backup_window" {
  type        = string
  default     = "03:00-04:00"
  description = "Preferred daily UTC window for automated backups. Must not overlap with maintenance_window."
}

variable "maintenance_window" {
  type        = string
  default     = "mon:04:00-mon:05:00"
  description = "Preferred weekly UTC window for maintenance. Must not overlap with backup_window."
}

variable "performance_insights_enabled" {
  type        = bool
  default     = false
  description = "Whether to enable Performance Insights. Recommended for production deployments. Free for 7-day retention; longer retention incurs cost."
}

variable "performance_insights_retention_period" {
  type        = number
  default     = 7
  description = "Retention period in days for Performance Insights data. 7 days is free; production deployments should use 731 days for long-term analysis."
}

variable "enabled_cloudwatch_logs_exports" {
  type        = list(string)
  default     = []
  description = "PostgreSQL log types to export to CloudWatch. Production deployments should set [\"postgresql\", \"upgrade\"]."
}

variable "monitoring_interval" {
  type        = number
  default     = 0
  description = "Interval in seconds for enhanced monitoring metrics. 0 disables enhanced monitoring. Production deployments should set 60."
}

variable "monitoring_role_name" {
  type        = string
  default     = null
  description = "Name of the IAM role for RDS enhanced monitoring. Required when monitoring_interval > 0."
}

variable "multi_az" {
  type        = bool
  default     = false
  description = "Whether to enable Multi-AZ for the RDS instance."
}

variable "skip_final_snapshot" {
  type        = bool
  default     = true
  description = "Whether to skip the final snapshot on deletion. Set to false for production deployments and provide a final_snapshot_identifier."
}

variable "final_snapshot_identifier" {
  type        = string
  default     = null
  description = "Identifier for the final snapshot when skip_final_snapshot is false. Required when skip_final_snapshot = false."
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Whether to enable deletion protection on the RDS instance. Set to true for production deployments."
}
