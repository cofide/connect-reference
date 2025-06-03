resource "cofide_connect_trust_zone" "tz_1" {
  name         = var.trust_zone_1_name
  trust_domain = var.trust_domain_1
}

resource "cofide_connect_cluster" "tz_1" {
  name               = var.cluster_1_name
  trust_zone_id      = cofide_connect_trust_zone.tz_1.id
  org_id             = cofide_connect_trust_zone.tz_1.org_id
  profile            = "kubernetes"
  kubernetes_context = var.cluster_1_kubernetes_context
  extra_helm_values  = var.cluster_1_extra_helm_values != "" ? file(var.cluster_1_extra_helm_values) : null

  trust_provider = {
    kind = "kubernetes"
  }

  external_server = false
}

resource "cofide_connect_trust_zone" "tz_2" {
  name         = var.trust_zone_2_name
  trust_domain = var.trust_domain_2
}

resource "cofide_connect_cluster" "tz_2" {
  name               = var.cluster_2_name
  trust_zone_id      = cofide_connect_trust_zone.tz_2.id
  org_id             = cofide_connect_trust_zone.tz_2.org_id
  profile            = "kubernetes"
  kubernetes_context = var.cluster_2_kubernetes_context
  extra_helm_values  = var.cluster_2_extra_helm_values != "" ? file(var.cluster_2_extra_helm_values) : null

  trust_provider = {
    kind = "kubernetes"
  }

  external_server = false
}

resource "cofide_connect_federation" "tz_1" {
  org_id               = cofide_connect_trust_zone.tz_1.org_id
  trust_zone_id        = cofide_connect_trust_zone.tz_1.id
  remote_trust_zone_id = cofide_connect_trust_zone.tz_2.id
}

resource "cofide_connect_federation" "tz_2" {
  org_id               = cofide_connect_trust_zone.tz_2.org_id
  trust_zone_id        = cofide_connect_trust_zone.tz_2.id
  remote_trust_zone_id = cofide_connect_trust_zone.tz_1.id
}

resource "cofide_connect_attestation_policy" "namespace" {
  name   = var.attestation_policy_name
  org_id = cofide_connect_trust_zone.tz_1.org_id

  kubernetes = {
    namespace_selector = {
      match_labels = {
        "kubernetes.io/metadata.name" = var.attestation_policy_namespace
      }
    }
  }
}

resource "cofide_connect_ap_binding" "tz_1_namespace" {
  org_id        = cofide_connect_trust_zone.tz_1.org_id
  trust_zone_id = cofide_connect_trust_zone.tz_1.id
  policy_id     = cofide_connect_attestation_policy.namespace.id

  federations = [
    {
      trust_zone_id = cofide_connect_trust_zone.tz_2.id
    }
  ]
}

resource "cofide_connect_ap_binding" "tz_2_namespace" {
  org_id        = cofide_connect_trust_zone.tz_2.org_id
  trust_zone_id = cofide_connect_trust_zone.tz_2.id
  policy_id     = cofide_connect_attestation_policy.namespace.id

  federations = [
    {
      trust_zone_id = cofide_connect_trust_zone.tz_1.id
    }
  ]
}
