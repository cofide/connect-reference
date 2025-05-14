variable "aws_region" {
  description = "The name of the AWS region."
  type        = string
}

variable "cluster_names" {
  description = "The names of the EKS clusters used to form the meshes."
  type        = list(string)
}

variable "admin_access_role" {
  description = "The name of the IAM role used for administrator access to the multi-mesh EKS clusters."
  type        = string
}

variable "developer_access_role" {
  description = "The name of the IAM role used for developer access to the multi-mesh EKS clusters."
  type        = string
}

variable "eks_node_group_capacity_type" {
  description = "The EKS node group capacity type for the Connect EKS cluster. Either SPOT or ON_DEMAND can be used."
  type        = string
  default     = "SPOT"
}

variable "oidc_provider_client_id" {
  description = "The client ID to associate with the respective OIDC provider on each multi-mesh EKS cluster."
  type        = string
}

variable "oidc_provider_issuer_url" {
  description = "The issuer URL to associate with the respective OIDC provider on each multi-mesh EKS cluster."
  type        = string
}
