resource "cofide_connect_trust_zone" "this" {
  name         = var.trust_zone_name
  trust_domain = var.trust_domain
}

resource "cofide_connect_cluster" "this" {
  name               = var.cluster_name
  trust_zone_id      = cofide_connect_trust_zone.this.id
  profile            = "kubernetes"
  oidc_issuer_url    = var.oidc_issuer_url
  external_server    = false
  kubernetes_context = ""

  trust_provider = {
    kind = "kubernetes"
  }
}
