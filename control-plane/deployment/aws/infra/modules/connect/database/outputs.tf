output "connect_db_name" {
  description = "Name of the Connect API database."
  value       = postgresql_database.connect.name
}

output "connect_db_user" {
  description = "Name of the PostgreSQL role for the Connect API. Use in rds-db:connect IAM permissions and Connect API datastore configuration."
  value       = postgresql_role.connect_api.name
}
