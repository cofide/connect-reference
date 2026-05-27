include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  default_config = {
    kms_key_alias                   = "alias/cofide-connect-control-plane-aws-reference-arch-bundles"
    kms_key_deletion_window_in_days = 7
  }

  unit_config_path = "${get_terragrunt_dir()}/common.local.hcl"
  has_local_config = fileexists(local.unit_config_path)
  user_config      = local.has_local_config ? read_terragrunt_config(local.unit_config_path).locals : {}
  merged_config    = merge(local.default_config, local.user_config)
}

terraform {
  source = "${get_repo_root()}//control-plane/deployment/aws/infra/modules/connect/bundle-bucket"
}

inputs = {
  # bucket_name has no default — S3 bucket names are globally unique and must be set in common.local.hcl.
  bucket_name                     = local.user_config.bucket_name
  kms_key_alias                   = local.merged_config.kms_key_alias
  kms_key_deletion_window_in_days = local.merged_config.kms_key_deletion_window_in_days
}
