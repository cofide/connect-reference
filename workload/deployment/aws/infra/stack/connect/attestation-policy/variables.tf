variable "connect_url" {
  type        = string
  description = "Cofide Connect API gRPC address in host:port form (e.g. example.cofide.dev:443). The provider prepends the connect. subdomain. No scheme."
}

variable "trust_zone_id" {
  type        = string
  description = "The ID of the trust zone to bind the attestation policy to."
}

variable "policy_name" {
  type        = string
  description = "The name of the attestation policy."
}

variable "spiffe_id_path" {
  type        = string
  description = "The SPIFFE ID path assigned to workloads matching this policy (e.g. ns/default/sa/my-app)."
}

variable "parent_id_path" {
  type        = string
  description = "The SPIFFE ID path of the parent node agent for workloads matching this policy."
}

variable "selectors" {
  type = list(object({
    type  = string
    value = string
  }))
  description = "The list of SPIRE selectors for this attestation policy."
}
