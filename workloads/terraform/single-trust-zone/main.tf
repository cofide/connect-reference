resource "cofide_connect_trust_zone" "this" {
  name         = var.trust_zone_name
  trust_domain = var.trust_domain
}

resource "cofide_connect_cluster" "this" {
  name               = var.cluster_name
  trust_zone_id      = cofide_connect_trust_zone.this.id
  org_id             = cofide_connect_trust_zone.this.org_id
  profile            = "kubernetes"
  kubernetes_context = var.cluster_kubernetes_context

  trust_provider = {
    kind = "kubernetes"
  }

  external_server = false
}

resource "cofide_connect_attestation_policy" "this" {
  name   = var.attestation_policy_name
  org_id = cofide_connect_trust_zone.this.org_id

  kubernetes = {
    namespace_selector = {
      match_labels = {
        "kubernetes.io/metadata.name" = var.attestation_policy_namespace
      }
    }
  }
}

resource "cofide_connect_ap_binding" "this" {
  org_id        = cofide_connect_trust_zone.this.org_id
  trust_zone_id = cofide_connect_trust_zone.this.id
  policy_id     = cofide_connect_attestation_policy.this.id
}
