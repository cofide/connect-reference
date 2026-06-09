output "role_arn" {
  description = "ARN of the IAM role for external-dns"
  value       = aws_iam_role.external_dns.arn
}
