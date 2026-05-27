output "spire_db_name" {
  description = "Name of the SPIRE server database."
  value       = postgresql_database.spire.name
}

output "spire_db_user" {
  description = "Name of the PostgreSQL role for the SPIRE server. Use in rds-db:connect IAM permissions and SPIRE datastore configuration."
  value       = postgresql_role.spire.name
}
