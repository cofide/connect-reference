output "iam_admin_username" {
  description = "Username of the IAM admin database role. Used by subsequent database units to connect via IAM token authentication."
  value       = postgresql_role.iam_admin.name
}
