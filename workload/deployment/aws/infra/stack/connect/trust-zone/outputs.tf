output "trust_domain" {
  description = "The SPIFFE trust domain for this trust zone."
  value       = cofide_connect_trust_zone.this.trust_domain
}

output "trust_zone_id" {
  description = "The ID of the trust zone registered with Cofide Connect."
  value       = cofide_connect_trust_zone.this.id
}

output "bundle_endpoint_url" {
  description = "The bundle endpoint URL for this trust zone, as assigned by Cofide Connect."
  value       = cofide_connect_trust_zone.this.bundle_endpoint_url
}

output "cluster_id" {
  description = "The ID of the cluster registered with Cofide Connect."
  value       = cofide_connect_cluster.this.id
}

output "cluster_name" {
  description = "The name of the cluster as registered with Cofide Connect."
  value       = cofide_connect_cluster.this.name
}
