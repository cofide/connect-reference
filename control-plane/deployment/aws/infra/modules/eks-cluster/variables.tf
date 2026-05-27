variable "cluster_role_name" {
  description = "Name of the IAM role for the EKS control plane"
  type        = string
}

variable "node_role_name" {
  description = "Name of the IAM role for the EKS worker nodes"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to deploy the cluster into"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of private subnets to deploy the cluster control plane and node groups into"
  type        = list(string)
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "enable_irsa" {
  description = "Create an IAM OIDC provider for the cluster, enabling IAM Roles for Service Accounts (IRSA). Not required when using EKS Pod Identity."
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Retention period in days for the EKS control plane CloudWatch log group"
  type        = number
  default     = 7
}

variable "addon_versions" {
  description = "Versions for each EKS managed addon. Must be compatible with var.cluster_version. Set pod_identity_agent to install the EKS Pod Identity agent; omit it if using IRSA instead."
  type = object({
    coredns            = string
    kube_proxy         = string
    vpc_cni            = string
    pod_identity_agent = optional(string)
  })
}

variable "cluster_access_mode" {
  description = "Controls EKS API server endpoint visibility. 'ssm' (default) keeps the endpoint private; 'public' exposes it publicly."
  type        = string
  default     = "ssm"

  validation {
    condition     = contains(["ssm", "public"], var.cluster_access_mode)
    error_message = "cluster_access_mode must be one of: ssm, public."
  }
}

variable "public_access_cidrs" {
  description = "CIDR blocks permitted to reach the public API server endpoint. Only used when cluster_access_mode is 'public'."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_admin_role_arns" {
  description = "IAM role ARNs to grant cluster-admin access via EKS access entries"
  type        = list(string)
  default     = []
}

variable "jump_security_group_id" {
  description = "Security group ID of the SSM jump instance. When set, an ingress rule is created allowing the jump instance to reach the API server. Leave null if not using a jump instance."
  type        = string
  default     = null
}

variable "node_groups" {
  description = "Map of node groups to create. Keys are used as Terraform state identifiers and are independent of the node group name."
  type = map(object({
    name            = string
    ami_type        = string
    instance_types  = list(string)
    subnet_ids      = list(string)
    min_size        = number
    max_size        = number
    capacity_type   = optional(string, "ON_DEMAND")
    max_unavailable = optional(number, 1)
    labels          = optional(map(string), {})
  }))
}

variable "cluster_sg_name" {
  description = "Name tag for the EKS control plane security group"
  type        = string
}

variable "node_sg_name" {
  description = "Name tag for the EKS worker node security group"
  type        = string
}

variable "kms_key_alias" {
  description = "Alias for the KMS key used for EKS secret envelope encryption. Must begin with 'alias/'."
  type        = string

  validation {
    condition     = startswith(var.kms_key_alias, "alias/")
    error_message = "kms_key_alias must begin with 'alias/'."
  }
}
