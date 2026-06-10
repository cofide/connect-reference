include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "dns" {
  config_path = "../../base/dns"

  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    zone_id = "Z0MOCKHOSTEDZONEID"
  }
}

dependency "bundle_bucket" {
  config_path = "../bundle-bucket"

  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    bucket_name                 = "mock-connect-bundles"
    bucket_arn                  = "arn:aws:s3:::mock-connect-bundles"
    bucket_regional_domain_name = "mock-connect-bundles.s3.eu-west-2.amazonaws.com"
    kms_key_arn                 = "arn:aws:kms:eu-west-2:000000000000:key/mock-kms-key-id"
  }
}

locals {
  default_config = {
    price_class = "PriceClass_100"
  }

  unit_config_path = "${get_terragrunt_dir()}/common.local.hcl"
  has_local_config = fileexists(local.unit_config_path)
  user_config      = local.has_local_config ? read_terragrunt_config(local.unit_config_path).locals : {}
  merged_config    = merge(local.default_config, local.user_config)

  user_hosted_zone_id              = try(local.user_config.hosted_zone_id, null)
  user_bucket_name                 = try(local.user_config.bucket_name, null)
  user_bucket_arn                  = try(local.user_config.bucket_arn, null)
  user_bucket_regional_domain_name = try(local.user_config.bucket_regional_domain_name, null)
  user_bucket_kms_key_arn          = try(local.user_config.bucket_kms_key_arn, null)
}

terraform {
  source = "${get_repo_root()}//control-plane/deployment/aws/infra/modules/connect/bundle-distribution"
}

inputs = {
  bundle_domain = local.user_config.bundle_domain
  price_class   = local.merged_config.price_class

  hosted_zone_id              = local.user_hosted_zone_id != null ? local.user_hosted_zone_id : try(dependency.dns.outputs.zone_id, null)
  bucket_name                 = local.user_bucket_name != null ? local.user_bucket_name : try(dependency.bundle_bucket.outputs.bucket_name, null)
  bucket_arn                  = local.user_bucket_arn != null ? local.user_bucket_arn : try(dependency.bundle_bucket.outputs.bucket_arn, null)
  bucket_regional_domain_name = local.user_bucket_regional_domain_name != null ? local.user_bucket_regional_domain_name : try(dependency.bundle_bucket.outputs.bucket_regional_domain_name, null)
  bucket_kms_key_arn          = local.user_bucket_kms_key_arn != null ? local.user_bucket_kms_key_arn : try(dependency.bundle_bucket.outputs.kms_key_arn, null)
}
