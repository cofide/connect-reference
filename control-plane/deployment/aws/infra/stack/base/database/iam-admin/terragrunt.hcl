include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "rds_instance" {
  config_path = "../rds-instance"

  # Allow skipping when db_identifier is provided directly in common.local.hcl
  # (e.g. deploying against an existing RDS instance).
  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    db_identifier = "mock-db"
  }
}

locals {
  default_config = {
    db_host            = "localhost"
    db_port            = 5432
    iam_admin_username = "iam_admin"
    aws_rds_iam_auth   = false
  }

  unit_config_path = "${get_terragrunt_dir()}/common.local.hcl"
  has_local_config = fileexists(local.unit_config_path)
  user_config      = local.has_local_config ? read_terragrunt_config(local.unit_config_path).locals : {}
  merged_config    = merge(local.default_config, local.user_config)

  user_db_identifier  = try(local.merged_config.db_identifier, null)
  user_db_actual_host = try(local.merged_config.db_actual_host, null)
  user_db_admin       = try(local.merged_config.db_admin_username, null)
}

terraform {
  source = "${get_repo_root()}//control-plane/deployment/aws/infra/modules/rds-iam-admin"
}

inputs = {
  db_identifier      = local.user_db_identifier != null ? local.user_db_identifier : dependency.rds_instance.outputs.db_identifier
  db_actual_host     = local.user_db_actual_host
  db_host            = local.merged_config.db_host
  db_port            = local.merged_config.db_port
  db_admin_username  = local.user_db_admin != null ? local.user_db_admin : local.merged_config.iam_admin_username
  aws_rds_iam_auth   = local.merged_config.aws_rds_iam_auth
  iam_admin_username = local.merged_config.iam_admin_username
}
