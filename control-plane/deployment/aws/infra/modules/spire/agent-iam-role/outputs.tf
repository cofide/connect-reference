output "role_arn" {
  description = "ARN of the SPIRE agent IAM role."
  value       = aws_iam_role.spire_agent.arn
}

output "role_name" {
  description = "Name of the SPIRE agent IAM role."
  value       = aws_iam_role.spire_agent.name
}
