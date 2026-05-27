include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "rds_instance" {
  config_path = "../../base/database/rds-instance"

  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    db_host = "mock-db.eu-west-2.rds.amazonaws.com"
    db_port = 5432
  }
}

dependency "database_iam_admin" {
  config_path = "../../base/database/iam-admin"

  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    iam_admin_username = "iam_admin"
  }
}

locals {
  default_config = {
    db_host          = "localhost"
    aws_rds_iam_auth = false
    spire_db_name    = "spire"
    spire_db_user    = "spire"
  }

  unit_config_path = "${get_terragrunt_dir()}/common.local.hcl"
  has_local_config = fileexists(local.unit_config_path)
  user_config      = local.has_local_config ? read_terragrunt_config(local.unit_config_path).locals : {}
  merged_config    = merge(local.default_config, local.user_config)

  user_db_actual_host = try(local.merged_config.db_actual_host, null)
  user_db_admin       = try(local.merged_config.db_admin_username, null)
  user_db_username    = try(local.merged_config.db_username, null)
  user_db_password    = try(local.merged_config.db_password, null)
}

terraform {
  source = "${get_repo_root()}//control-plane/deployment/aws/infra/modules/spire/database"
}

inputs = {
  db_actual_host    = local.user_db_actual_host != null ? local.user_db_actual_host : dependency.rds_instance.outputs.db_host
  db_host           = local.merged_config.db_host
  db_port           = dependency.rds_instance.outputs.db_port
  db_admin_username = local.user_db_admin != null ? local.user_db_admin : dependency.database_iam_admin.outputs.iam_admin_username
  db_username       = local.user_db_username
  db_password       = local.user_db_password
  aws_rds_iam_auth  = local.merged_config.aws_rds_iam_auth
  spire_db_name     = local.merged_config.spire_db_name
  spire_db_user     = local.merged_config.spire_db_user
}
