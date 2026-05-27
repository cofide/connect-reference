variable "db_actual_host" {
  type        = string
  default     = null
  description = "Actual RDS hostname used to generate the IAM authentication token. Required when db_username and db_password are not set."
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

variable "db_admin_username" {
  type        = string
  default     = "iam_admin"
  description = "Database role to connect as when using IAM token authentication. Must have rds_iam and rds_superuser grants."
}

variable "db_username" {
  type        = string
  default     = null
  description = "Database username. When set alongside db_password, skips IAM token generation — use this to connect to a non-RDS or non-IAM database."
}

variable "db_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "Database password. When set alongside db_username, skips IAM token generation."
}

variable "aws_rds_iam_auth" {
  type        = bool
  default     = false
  description = "When true, uses the postgresql provider's native RDS IAM authentication — the provider generates tokens internally using db_host as the RDS endpoint. Use this when connecting directly to the RDS endpoint without an SSM tunnel. When false (default), tokens are generated via aws rds generate-db-auth-token using db_actual_host, for use with SSM tunnel connections where db_host is localhost."
}
