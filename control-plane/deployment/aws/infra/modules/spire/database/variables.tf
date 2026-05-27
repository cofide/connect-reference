variable "spire_db_name" {
  type        = string
  default     = "spire"
  description = "Name of the database to create for the SPIRE server datastore."
}

variable "spire_db_user" {
  type        = string
  default     = "spire"
  description = "Name of the PostgreSQL role to create for the SPIRE server. Granted rds_iam for IAM-only authentication — no password is set."
}
