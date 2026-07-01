variable "role_name" {
  type        = string
  description = "Name for the SPIRE agent IAM role."
}

variable "iam_mode" {
  type        = string
  default     = "pod_identity"
  description = "IAM binding mode. 'pod_identity' uses EKS Pod Identity (requires eks-pod-identity-agent add-on). 'irsa' uses IAM Roles for Service Accounts (requires enable_irsa = true in the cluster unit and oidc_provider_arn to be set)."

  validation {
    condition     = contains(["pod_identity", "irsa"], var.iam_mode)
    error_message = "iam_mode must be 'pod_identity' or 'irsa'."
  }
}

variable "namespace" {
  type        = string
  default     = "spire-system"
  description = "Kubernetes namespace the SPIRE agent runs in. Used for the Pod Identity association and IRSA trust condition."
}

variable "service_account_name" {
  type        = string
  default     = "spire-agent"
  description = "Kubernetes service account name for the SPIRE agent. Used for the Pod Identity association and IRSA trust condition."
}

variable "cluster_name" {
  type        = string
  default     = null
  description = "EKS cluster name. Required for Pod Identity association."
}

variable "oidc_provider_arn" {
  type        = string
  default     = null
  description = "ARN of the EKS cluster OIDC provider. Required for IRSA mode."

  validation {
    condition     = var.iam_mode != "irsa" || var.oidc_provider_arn != null
    error_message = "oidc_provider_arn must be set when iam_mode is 'irsa'."
  }
}

