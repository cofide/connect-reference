output "region" {
  description = "AWS region in which the EKS cluster is deployed"
  value       = data.aws_region.current.region
}

output "node_security_group_id" {
  description = "ID of the EKS worker node security group."
  value       = aws_security_group.eks_nodes.id
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint_hostname" {
  description = "EKS API server hostname (without https://) — used as the SSM port forwarding target host"
  value       = trimprefix(aws_eks_cluster.this.endpoint, "https://")
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for the cluster. Non-null only when enable_irsa is true."
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.eks[0].arn : null
}
