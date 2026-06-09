variable "connect_db_name" {
  type        = string
  description = "Name of the database to create for the Connect API datastore."
}

variable "connect_db_user" {
  type        = string
  description = "Name of the PostgreSQL role to create for the Connect API. Granted rds_iam for IAM-only authentication — no password is set."
}
