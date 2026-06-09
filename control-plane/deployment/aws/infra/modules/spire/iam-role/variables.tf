variable "role_name" {
  type        = string
  description = "Name for the SPIRE server IAM role."
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
  default     = "spire-server"
  description = "Kubernetes namespace the SPIRE server runs in. Used for the Pod Identity association and IRSA trust condition."
}

variable "service_account_name" {
  type        = string
  default     = "spire-server"
  description = "Kubernetes service account name for the SPIRE server. Used for the Pod Identity association and IRSA trust condition."
}

variable "cluster_name" {
  type        = string
  default     = null
  description = "EKS cluster name. Required for Pod Identity association. Reads from the cluster unit output when not set."
}

variable "oidc_provider_arn" {
  type        = string
  default     = null
  description = "ARN of the EKS cluster OIDC provider. Required for IRSA mode. Reads from the cluster unit output when not set."

  validation {
    condition     = var.iam_mode != "irsa" || var.oidc_provider_arn != null
    error_message = "oidc_provider_arn must be set when iam_mode is 'irsa'."
  }
}

variable "db_resource_id" {
  type        = string
  default     = null
  description = "RDS DbiResourceId of the database instance. Used to construct the rds-db:connect IAM permission ARN. Reads from the base/database/rds-instance unit output when not set."
}

variable "db_username" {
  type        = string
  default     = null
  description = "PostgreSQL role name for the SPIRE server database user. Used to construct the rds-db:connect IAM permission ARN. Reads from the spire-server-db unit output when not set."
}
