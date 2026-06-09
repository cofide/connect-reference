include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "cluster" {
  config_path = "../../eks-cluster/cluster"

  # Allow this dependency to be skipped when cluster_name is provided directly
  # in common.local.hcl (e.g. deploying against an existing cluster).
  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    node_security_group_id = "sg-00000000000000000"
  }
}

dependency "vpc" {
  config_path = "../../vpc"

  # Allow this dependency to be skipped when vpc_id and subnet_ids are
  # provided directly in common.local.hcl.
  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    vpc_id           = "vpc-00000000000000000"
    intra_subnet_ids = { "mock" = "subnet-00000000000000000" }
  }
}

dependency "jump" {
  config_path = "../../jump"

  # Allow this dependency to be skipped when the jump unit has not been deployed
  # or jump_security_group_id is provided directly in common.local.hcl.
  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    security_group_id = "sg-00000000000000000"
  }
}

locals {
  default_config = {
    db_identifier        = "cofide-connect-control-plane-aws-reference-arch"
    subnet_group_name    = "cofide-connect-control-plane-aws-reference-arch"
    security_group_name  = "cofide-connect-control-plane-aws-reference-arch-rds"
    parameter_group_name = "cofide-connect-control-plane-aws-reference-arch"
    kms_key_alias        = "alias/cofide-connect-control-plane-aws-reference-arch-rds-storage"
    secret_kms_key_alias = "alias/cofide-connect-control-plane-aws-reference-arch-rds-secret"

    db_username = "postgres"

    db_instance_class     = "db.t3.medium"
    postgres_version      = "17"
    storage_type          = "gp3"
    allocated_storage     = 20
    max_allocated_storage = 100
    multi_az              = false

    backup_retention_period = 1
    backup_window           = "03:00-04:00"
    maintenance_window      = "mon:04:00-mon:05:00"

    performance_insights_enabled          = false
    performance_insights_retention_period = 7
    # Disabled by default for the reference deployment to reduce cost.
    # For production, enable log exports and enhanced monitoring in common.local.hcl.
    enabled_cloudwatch_logs_exports = []
    monitoring_interval             = 0
    monitoring_role_name            = "cofide-connect-control-plane-aws-reference-arch-rds-monitoring"

    # Intentionally permissive for the reference deployment to allow clean teardown.
    # For production, set deletion_protection = true, skip_final_snapshot = false,
    # and provide a final_snapshot_identifier in common.local.hcl.
    skip_final_snapshot       = true
    final_snapshot_identifier = null
    deletion_protection       = false
  }

  unit_config_path = "${get_terragrunt_dir()}/common.local.hcl"
  has_local_config = fileexists(local.unit_config_path)
  user_config      = local.has_local_config ? read_terragrunt_config(local.unit_config_path).locals : {}
  merged_config    = merge(local.default_config, local.user_config)

  # Extracted from merged_config if set; null otherwise. The actual selection
  # between these and the dependency outputs happens in inputs below.
  user_node_sg_id = try(local.merged_config.node_security_group_id, null)
  user_vpc_id     = try(local.merged_config.vpc_id, null)
  user_subnet_ids = try(local.merged_config.subnet_ids, null)
  user_jump_sg_id = try(local.merged_config.jump_security_group_id, null)

}

terraform {
  source = "${get_repo_root()}//control-plane/deployment/aws/infra/modules/rds-instance"
}

inputs = {
  ingress_security_groups = merge(
    {
      nodes = {
        security_group_id = local.user_node_sg_id != null ? local.user_node_sg_id : try(dependency.cluster.outputs.node_security_group_id, null)
        description       = "PostgreSQL from EKS worker nodes"
      }
    },
    try(coalesce(local.user_jump_sg_id, try(dependency.jump.outputs.security_group_id, null)), null) != null ? {
      jump = {
        security_group_id = local.user_jump_sg_id != null ? local.user_jump_sg_id : dependency.jump.outputs.security_group_id
        description       = "PostgreSQL from SSM jump instance"
      }
    } : {},
  )
  node_security_group_id = local.user_node_sg_id != null ? local.user_node_sg_id : try(dependency.cluster.outputs.node_security_group_id, null)
  jump_security_group_id = local.user_jump_sg_id != null ? local.user_jump_sg_id : try(dependency.jump.outputs.security_group_id, null)
  vpc_id                 = local.user_vpc_id != null ? local.user_vpc_id : dependency.vpc.outputs.vpc_id
  subnet_ids             = local.user_subnet_ids != null ? local.user_subnet_ids : values(dependency.vpc.outputs.intra_subnet_ids)

  db_identifier        = local.merged_config.db_identifier
  subnet_group_name    = local.merged_config.subnet_group_name
  security_group_name  = local.merged_config.security_group_name
  parameter_group_name = local.merged_config.parameter_group_name
  kms_key_alias        = local.merged_config.kms_key_alias
  secret_kms_key_alias = local.merged_config.secret_kms_key_alias

  db_username = local.merged_config.db_username

  db_instance_class     = local.merged_config.db_instance_class
  postgres_version      = local.merged_config.postgres_version
  storage_type          = local.merged_config.storage_type
  allocated_storage     = local.merged_config.allocated_storage
  max_allocated_storage = local.merged_config.max_allocated_storage
  multi_az              = local.merged_config.multi_az

  backup_retention_period = local.merged_config.backup_retention_period
  backup_window           = local.merged_config.backup_window
  maintenance_window      = local.merged_config.maintenance_window

  performance_insights_enabled          = local.merged_config.performance_insights_enabled
  performance_insights_retention_period = local.merged_config.performance_insights_retention_period
  enabled_cloudwatch_logs_exports       = local.merged_config.enabled_cloudwatch_logs_exports
  monitoring_interval                   = local.merged_config.monitoring_interval
  monitoring_role_name                  = local.merged_config.monitoring_role_name

  skip_final_snapshot       = local.merged_config.skip_final_snapshot
  final_snapshot_identifier = local.merged_config.final_snapshot_identifier
  deletion_protection       = local.merged_config.deletion_protection
}
