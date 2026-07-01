resource "cofide_connect_attestation_policy" "this" {
  name = var.policy_name

  static = {
    spiffe_id_path = var.spiffe_id_path
    parent_id_path = var.parent_id_path
    selectors      = var.selectors
    store_svid     = true
  }
}

resource "cofide_connect_ap_binding" "this" {
  trust_zone_id = var.trust_zone_id
  policy_id     = cofide_connect_attestation_policy.this.id
}
