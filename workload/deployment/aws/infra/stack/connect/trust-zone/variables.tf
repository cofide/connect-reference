variable "connect_url" {
  type        = string
  description = "Cofide Connect API gRPC address in host:port form (e.g. example.cofide.dev:443). The provider prepends the connect. subdomain. No scheme."
}

variable "trust_zone_name" {
  type        = string
  description = "The name of the trust zone to register with Cofide Connect."
}

variable "trust_domain" {
  type        = string
  description = "The SPIFFE trust domain for this trust zone (e.g. trust-zone.example.cofide.dev)."
}

variable "cluster_name" {
  type        = string
  description = "The name of the cluster to register with Cofide Connect."
}

variable "oidc_issuer_url" {
  type        = string
  description = "OIDC issuer URL of the EKS cluster (e.g. https://oidc.eks.<region>.amazonaws.com/id/<id>)."
}
