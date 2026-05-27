output "role_arn" {
  description = "ARN of the IAM role for cert-manager"
  value       = aws_iam_role.cert_manager.arn
}
