variable "trust_zone_1_name" {
  type        = string
  description = "The name of trust zone 1."
}

variable "trust_domain_1" {
  type        = string
  description = "The trust domain associated with trust zone 1."
}

variable "cluster_1_name" {
  type        = string
  description = "The name of the cluster associated with trust zone 1."
}

variable "cluster_1_kubernetes_context" {
  type        = string
  description = "The Kubernetes context for the cluster associated with trust zone 1."
}

variable "cluster_1_extra_helm_values" {
  type        = string
  description = "The extra helm values for the cluster associated with trust zone 1."
}

variable "attestation_policy_name" {
  type        = string
  description = "The name of the namespace attestation policy."
}

variable "attestation_policy_namespace" {
  type        = string
  description = "The namespace to associate with the namespace attestation policy."
}

variable "trust_zone_2_name" {
  type        = string
  description = "The name of trust zone 2."
}

variable "trust_domain_2" {
  type        = string
  description = "The trust domain associated with trust zone 2."
}

variable "cluster_2_name" {
  type        = string
  description = "The name of the cluster associated with trust zone 2."
}

variable "cluster_2_kubernetes_context" {
  type        = string
  description = "The Kubernetes context for the cluster associated with trust zone 2."
}

variable "cluster_2_extra_helm_values" {
  type        = string
  description = "The extra helm values for the cluster associated with trust zone 2."
}
