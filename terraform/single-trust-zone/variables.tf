variable "trust_zone_name" {
  type        = string
  description = "The name of the trust zone."
}

variable "trust_domain" {
  type        = string
  description = "The trust domain associated with the trust zone."
}

variable "cluster_name" {
  type        = string
  description = "The name of the cluster associated with the trust zone."
}

variable "cluster_kubernetes_context" {
  type        = string
  description = "The Kubernetes context for the cluster associated with the trust zone."
}

variable "attestation_policy_name" {
  type        = string
  description = "The name of the namespace attestation policy."
}

variable "attestation_policy_namespace" {
  type        = string
  description = "The namespace to associate with the namespace attestation policy."
}
