variable "cluster_name" {
  description = "Name of the EKS cluster to create the Pod Identity association in. Required for Pod Identity mode."
  type        = string
  default     = null

  validation {
    condition     = var.iam_mode != "pod_identity" || var.cluster_name != null
    error_message = "cluster_name must be set when iam_mode is 'pod_identity'."
  }
}

variable "role_name" {
  description = "Name of the IAM role for the AWS Load Balancer Controller"
  type        = string
}

variable "policy_name" {
  description = "Name of the IAM policy for the AWS Load Balancer Controller"
  type        = string
}

variable "iam_mode" {
  description = "IAM authentication mode for the AWS Load Balancer Controller. 'pod_identity' uses EKS Pod Identity; 'irsa' uses IAM Roles for Service Accounts."
  type        = string
  default     = "pod_identity"

  validation {
    condition     = contains(["pod_identity", "irsa"], var.iam_mode)
    error_message = "iam_mode must be one of: pod_identity, irsa."
  }
}

variable "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for the EKS cluster. Required when iam_mode is 'irsa'."
  type        = string
  default     = null

  validation {
    condition     = var.iam_mode != "irsa" || var.oidc_provider_arn != null
    error_message = "oidc_provider_arn must be set when iam_mode is 'irsa'."
  }
}

variable "namespace" {
  description = "Kubernetes namespace that the AWS Load Balancer Controller runs in"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "Kubernetes service account name for the AWS Load Balancer Controller"
  type        = string
  default     = "aws-load-balancer-controller"
}
