output "role_arn" {
  description = "ARN of the Connect API IAM role."
  value       = aws_iam_role.connect_api.arn
}

output "role_name" {
  description = "Name of the Connect API IAM role."
  value       = aws_iam_role.connect_api.name
}
