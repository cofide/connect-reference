include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "cluster" {
  config_path = "../../base/eks-cluster/cluster"

  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    cluster_name      = "mock-cluster"
    oidc_provider_arn = "arn:aws:iam::012345678901:oidc-provider/oidc.eks.eu-west-2.amazonaws.com/id/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
  }
}

dependency "rds_instance" {
  config_path = "../../base/database/rds-instance"

  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    db_resource_id = "db-MOCKRESOURCEID"
  }
}

dependency "spire_server_database" {
  config_path = "../database"

  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    spire_db_user = "spire"
  }
}

locals {
  default_config = {
    role_name       = "cofide-connect-control-plane-aws-reference-arch-spire-server"
    iam_mode        = "pod_identity"
    namespace       = "spire-server"
    service_account = "spire-server"
  }

  unit_config_path = "${get_terragrunt_dir()}/common.local.hcl"
  has_local_config = fileexists(local.unit_config_path)
  user_config      = local.has_local_config ? read_terragrunt_config(local.unit_config_path).locals : {}
  merged_config    = merge(local.default_config, local.user_config)

  user_cluster_name      = try(local.merged_config.cluster_name, null)
  user_oidc_provider_arn = try(local.merged_config.oidc_provider_arn, null)
  user_db_resource_id    = try(local.merged_config.db_resource_id, null)
  user_db_username       = try(local.merged_config.db_username, null)
}

terraform {
  source = "${get_repo_root()}//control-plane/deployment/aws/infra/modules/spire/iam-role"
}

inputs = {
  role_name       = local.merged_config.role_name
  iam_mode        = local.merged_config.iam_mode
  namespace       = local.merged_config.namespace
  service_account = local.merged_config.service_account

  cluster_name      = local.user_cluster_name != null ? local.user_cluster_name : try(dependency.cluster.outputs.cluster_name, null)
  oidc_provider_arn = local.user_oidc_provider_arn != null ? local.user_oidc_provider_arn : try(dependency.cluster.outputs.oidc_provider_arn, null)

  db_resource_id = local.user_db_resource_id != null ? local.user_db_resource_id : try(dependency.rds_instance.outputs.db_resource_id, null)
  db_username    = local.user_db_username != null ? local.user_db_username : try(dependency.spire_server_database.outputs.spire_db_user, null)
}
