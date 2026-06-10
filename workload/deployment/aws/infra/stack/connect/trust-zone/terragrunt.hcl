include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "cluster" {
  config_path = "../../eks-cluster/cluster"

  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    oidc_issuer_url = "https://oidc.eks.eu-west-2.amazonaws.com/id/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
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
    trust_zone_name = "connect-trust-zone-aws-reference-arch"
    cluster_name    = "connect-trust-zone-aws-reference-arch"
  }

  unit_config_path = "${get_terragrunt_dir()}/common.local.hcl"
  has_local_config = fileexists(local.unit_config_path)
  user_config      = local.has_local_config ? read_terragrunt_config(local.unit_config_path).locals : {}
  merged_config    = merge(local.default_config, local.user_config)

  # trust_domain has no default — it must be set in common.local.hcl.
  trust_domain = local.merged_config.trust_domain

  user_connect_url     = try(local.merged_config.connect_url, null)
  user_oidc_issuer_url = try(local.merged_config.oidc_issuer_url, null)
}

terraform {
  source = "."
}

inputs = {
  connect_url = local.user_connect_url != null ? local.user_connect_url : "${dependency.cp_dns.outputs.zone_name}:443"

  trust_zone_name = local.merged_config.trust_zone_name
  trust_domain    = local.trust_domain
  cluster_name    = local.merged_config.cluster_name

  oidc_issuer_url = local.user_oidc_issuer_url != null ? local.user_oidc_issuer_url : dependency.cluster.outputs.oidc_issuer_url
}
