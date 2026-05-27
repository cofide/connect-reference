include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "rds_instance" {
  config_path = "../../base/database/rds-instance"

  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    db_resource_id = "db-MOCKRESOURCEID"
  }
}

dependency "connect_database" {
  config_path = "../database"

  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    connect_db_user = "connect_api"
  }
}

dependency "bundle_bucket" {
  config_path = "../bundle-bucket"

  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    bucket_arn  = "arn:aws:s3:::mock-connect-bundles"
    kms_key_arn = "arn:aws:kms:eu-west-2:012345678901:key/mock-key-id"
  }
}

locals {
  default_config = {
    role_name = "cofide-connect-control-plane-aws-reference-arch-connect-api"
  }

  unit_config_path = "${get_terragrunt_dir()}/common.local.hcl"
  has_local_config = fileexists(local.unit_config_path)
  user_config      = local.has_local_config ? read_terragrunt_config(local.unit_config_path).locals : {}
  merged_config    = merge(local.default_config, local.user_config)

  user_db_resource_id            = try(local.merged_config.db_resource_id, null)
  user_db_username               = try(local.merged_config.db_username, null)
  user_bundle_bucket_arn         = try(local.merged_config.bundle_bucket_arn, null)
  user_bundle_bucket_kms_key_arn = try(local.merged_config.bundle_bucket_kms_key_arn, null)
}

terraform {
  source = "${get_repo_root()}//control-plane/deployment/aws/infra/modules/connect/iam-role"
}

inputs = {
  role_name         = local.merged_config.role_name
  spire_oidc_domain = local.merged_config.spire_oidc_domain
  spiffe_id         = local.merged_config.spiffe_id

  bundle_bucket_arn         = local.user_bundle_bucket_arn != null ? local.user_bundle_bucket_arn : try(dependency.bundle_bucket.outputs.bucket_arn, null)
  bundle_bucket_kms_key_arn = local.user_bundle_bucket_kms_key_arn != null ? local.user_bundle_bucket_kms_key_arn : try(dependency.bundle_bucket.outputs.kms_key_arn, null)

  db_resource_id = local.user_db_resource_id != null ? local.user_db_resource_id : try(dependency.rds_instance.outputs.db_resource_id, null)
  db_username    = local.user_db_username != null ? local.user_db_username : try(dependency.connect_database.outputs.connect_db_user, null)
}
