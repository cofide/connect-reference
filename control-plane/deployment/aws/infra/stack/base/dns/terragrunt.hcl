include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  unit_config_path = "${get_terragrunt_dir()}/common.local.hcl"
  has_local_config = fileexists(local.unit_config_path)
  user_config      = local.has_local_config ? read_terragrunt_config(local.unit_config_path).locals : {}

  # zone_name has no default — it must be set in common.local.hcl.
  # cloudflare_zone_id and cloudflare_record_name are optional.
  zone_name              = local.user_config.zone_name
  cloudflare_zone_id     = try(local.user_config.cloudflare_zone_id, null)
  cloudflare_record_name = try(local.user_config.cloudflare_record_name, null)
}

terraform {
  source = "${get_repo_root()}//control-plane/deployment/aws/infra/modules/dns"
}

inputs = {
  zone_name              = local.zone_name
  cloudflare_zone_id     = local.cloudflare_zone_id
  cloudflare_record_name = local.cloudflare_record_name
}
