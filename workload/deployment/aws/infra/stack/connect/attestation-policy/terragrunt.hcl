include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "trust_zone" {
  config_path = "../trust-zone"

  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    trust_zone_id = "00000000-0000-0000-0000-000000000000"
  }
}

dependency "cp_dns" {
  config_path = "${get_repo_root()}/control-plane/deployment/aws/infra/stack/base/dns"

  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    zone_name = "example.cofide.dev"
  }
}

locals {
  default_config = {
    policy_name = "connect-trust-zone-aws-reference-arch-svidstore"
  }

  unit_config_path = "${get_terragrunt_dir()}/common.local.hcl"
  local_config     = read_terragrunt_config(local.unit_config_path).locals
  merged_config    = merge(local.default_config, local.local_config)

  # spiffe_id_path, parent_id_path, and selectors have no defaults — they must be set in common.local.hcl.
  spiffe_id_path = local.merged_config.spiffe_id_path
  parent_id_path = local.merged_config.parent_id_path
  selectors      = local.merged_config.selectors

  user_connect_url = try(local.merged_config.connect_url, null)
}

terraform {
  source = "."
}

inputs = {
  connect_url = local.user_connect_url != null ? local.user_connect_url : "${dependency.cp_dns.outputs.zone_name}:443"

  trust_zone_id  = dependency.trust_zone.outputs.trust_zone_id
  policy_name    = local.merged_config.policy_name
  spiffe_id_path = local.spiffe_id_path
  parent_id_path = local.parent_id_path
  selectors      = local.selectors
}
