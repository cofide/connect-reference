variable "db_identifier" {
  type        = string
  default     = null
  description = "RDS DB instance identifier. Used to look up the master user secret from Secrets Manager when db_username and db_password are not set."
}

variable "db_username" {
  type        = string
  default     = null
  description = "Database username. When set alongside db_password, skips the Secrets Manager lookup."
}

variable "db_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "Database password. When set alongside db_username, skips the Secrets Manager lookup."
}

variable "db_host" {
  type        = string
  default     = "localhost"
  description = "Hostname for database connections. Defaults to localhost for use with an active SSM port-forwarding tunnel."
}

variable "db_port" {
  type        = number
  default     = 5432
  description = "Port for database connections."
}

variable "db_actual_host" {
  type        = string
  default     = null
  description = "Actual RDS hostname used to generate IAM authentication tokens when connecting via SSM tunnel. When set, IAM token auth is used instead of Secrets Manager. Leave null to use Secrets Manager (default bootstrap path)."
}

variable "aws_rds_iam_auth" {
  type        = bool
  default     = false
  description = "When true, uses the postgresql provider's native RDS IAM authentication — the provider generates tokens internally using db_host as the RDS endpoint. Use this when connecting directly to the RDS endpoint without an SSM tunnel. When false (default), credentials are fetched from Secrets Manager using db_identifier."
}

variable "db_admin_username" {
  type        = string
  default     = "iam_admin"
  description = "Database role to connect as when aws_rds_iam_auth is true. Must have rds_iam and rds_superuser grants."
}
