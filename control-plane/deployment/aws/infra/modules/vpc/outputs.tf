output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "Map of private subnet IDs keyed by the subnet map key from var.private_subnets"
  value       = { for k, s in aws_subnet.private : k => s.id }
}

output "public_subnet_ids" {
  description = "Map of public subnet IDs keyed by the subnet map key from var.public_subnets"
  value       = { for k, s in aws_subnet.public : k => s.id }
}

output "intra_subnet_ids" {
  description = "Map of intra subnet IDs keyed by the subnet map key from var.intra_subnets"
  value       = { for k, s in aws_subnet.intra : k => s.id }
}
