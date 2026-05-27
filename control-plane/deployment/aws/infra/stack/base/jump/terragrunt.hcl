include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "vpc" {
  config_path = "../vpc"

  # Allow this dependency to be skipped when vpc_id and subnet_id are provided
  # directly in common.local.hcl (e.g. deploying into an existing VPC).
  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = { "mock" = "subnet-00000000000000000" }
  }
}

locals {
  default_config = {
    role_name     = "cofide-connect-control-plane-aws-reference-arch-jump"
    sg_name       = "cofide-connect-control-plane-aws-reference-arch-jump"
    instance_name = "cofide-connect-control-plane-aws-reference-arch-jump"
    instance_type = "t3.micro"
  }

  unit_config_path = "${get_terragrunt_dir()}/common.local.hcl"
  has_local_config = fileexists(local.unit_config_path)
  user_config      = local.has_local_config ? read_terragrunt_config(local.unit_config_path).locals : {}
  merged_config    = merge(local.default_config, local.user_config)

  # Extracted from merged_config if set; null otherwise. The actual selection
  # between these and the networking dependency outputs happens in inputs below.
  user_vpc_id    = try(local.merged_config.vpc_id, null)
  user_subnet_id = try(local.merged_config.subnet_id, null)
}

terraform {
  source = "${get_repo_root()}//control-plane/deployment/aws/infra/modules/jump"
}

inputs = {
  vpc_id    = local.user_vpc_id != null ? local.user_vpc_id : dependency.vpc.outputs.vpc_id
  subnet_id = local.user_subnet_id != null ? local.user_subnet_id : values(dependency.vpc.outputs.private_subnet_ids)[0]

  role_name     = local.merged_config.role_name
  sg_name       = local.merged_config.sg_name
  instance_name = local.merged_config.instance_name
  instance_type = local.merged_config.instance_type
}
