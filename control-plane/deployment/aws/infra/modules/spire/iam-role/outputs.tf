output "role_arn" {
  description = "ARN of the SPIRE server IAM role."
  value       = aws_iam_role.spire_server.arn
}

output "role_name" {
  description = "Name of the SPIRE server IAM role."
  value       = aws_iam_role.spire_server.name
}
