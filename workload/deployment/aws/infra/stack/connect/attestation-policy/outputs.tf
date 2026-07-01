output "policy_id" {
  description = "The ID of the attestation policy registered with Cofide Connect."
  value       = cofide_connect_attestation_policy.this.id
}

output "binding_id" {
  description = "The ID of the attestation policy binding."
  value       = cofide_connect_ap_binding.this.id
}
