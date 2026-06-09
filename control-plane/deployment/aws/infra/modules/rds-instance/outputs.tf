output "db_identifier" {
  description = "RDS DB instance identifier."
  value       = aws_db_instance.this.identifier
}

output "db_endpoint" {
  description = "Connection endpoint for the RDS instance (host:port)."
  value       = aws_db_instance.this.endpoint
}

output "db_host" {
  description = "Hostname of the RDS instance."
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Port the RDS instance listens on."
  value       = aws_db_instance.this.port
}

output "db_resource_id" {
  description = "RDS DbiResourceId — used to construct the rds-db:connect IAM permission ARN."
  value       = aws_db_instance.this.resource_id
}

output "db_username" {
  description = "Master username for the RDS instance."
  value       = aws_db_instance.this.username
}
