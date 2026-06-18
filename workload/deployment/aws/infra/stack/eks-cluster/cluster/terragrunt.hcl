include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  # Path to the control-plane Terragrunt stack, used for cross-stack dependencies.
  # VPC and jump dependencies are read from there by default; set vpc_id /
  # private_subnet_ids / jump_security_group_id in common.local.hcl to deploy
  # into a different VPC without this cross-stack reference.
  control_plane_stack = "${get_repo_root()}/control-plane/deployment/aws/infra/stack"

  default_config = {
    cluster_name    = "cofide-connect-trust-zone-aws-reference-arch"
    cluster_version = "1.35"

    cluster_role_name = "cofide-connect-trust-zone-aws-reference-arch-cluster"
    node_role_name    = "cofide-connect-trust-zone-aws-reference-arch-node"
    cluster_sg_name   = "cofide-connect-trust-zone-aws-reference-arch-cluster"
    node_sg_name      = "cofide-connect-trust-zone-aws-reference-arch-nodes"
    kms_key_alias     = "alias/cofide-connect-trust-zone-aws-reference-arch-eks-secrets"

    # Addon versions must be compatible with cluster_version.
    # Run `aws eks describe-addon-versions --kubernetes-version <version>` to list available versions.
    # Set pod_identity_agent to a version string to enable EKS Pod Identity; omit (null) to use IRSA instead.
    addon_versions = {
      coredns            = "v1.14.2-eksbuild.4"
      kube_proxy         = "v1.35.3-eksbuild.8"
      vpc_cni            = "v1.21.2-eksbuild.2"
      pod_identity_agent = "v1.3.10-eksbuild.3"
    }

    # Set to "public" to expose the API server endpoint publicly and skip the
    # SSM jump instance. Useful for developer environments without VPC access.
    cluster_access_mode = "ssm"

    # Restrict to known source CIDRs (e.g. a corporate egress IP) when
    # cluster_access_mode is "public". Defaults to unrestricted.
    public_access_cidrs = ["0.0.0.0/0"]

    cluster_admin_role_arns = []

    log_retention_days = 7

    # Set to true to create an IAM OIDC provider, enabling IRSA for controller pods.
    # Leave false when using EKS Pod Identity (the default).
    enable_irsa = false

    node_groups = {
      workers = {
        name     = "cofide-connect-trust-zone-aws-reference-arch-workers"
        ami_type = "AL2023_ARM_64_STANDARD"
        # m7g.xlarge: 4 vCPU / 16 GB RAM. Graviton3 offers better price/performance
        # than equivalent x86_64 instances. Requires ARM64 container images — all
        # components in this reference architecture support ARM64.
        instance_types = ["m7g.xlarge"]
        # subnet_ids defaults to all private subnets; set explicitly to pin to specific AZs.
        subnet_ids = []
        min_size   = 2
        max_size   = 3
      }
    }
  }

  unit_config_path = "${get_terragrunt_dir()}/common.local.hcl"
  has_local_config = fileexists(local.unit_config_path)
  user_config      = local.has_local_config ? read_terragrunt_config(local.unit_config_path).locals : {}
  merged_config    = merge(local.default_config, local.user_config)

  # Extracted from merged_config if set; null otherwise. The actual selection
  # between these and the networking dependency outputs happens in inputs below,
  # where dependency references are valid.
  user_vpc_id             = try(local.merged_config.vpc_id, null)
  user_private_subnet_ids = try(local.merged_config.private_subnet_ids, null)
  user_jump_sg_id         = try(local.merged_config.jump_security_group_id, null)
}

dependency "vpc" {
  config_path = "${local.control_plane_stack}/base/vpc"

  # Allow this dependency to be skipped when vpc_id and private_subnet_ids are
  # provided directly in common.local.hcl (e.g. deploying into a different VPC).
  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = { "mock" = "subnet-00000000000000000" }
  }
}

dependency "jump" {
  config_path = "${local.control_plane_stack}/base/jump"

  # Allow this dependency to be skipped when jump_security_group_id is provided
  # directly in common.local.hcl.
  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    security_group_id = "sg-00000000000000000"
  }
}

terraform {
  source = "${get_repo_root()}//control-plane/deployment/aws/infra/modules/eks-cluster"
}

inputs = {
  cluster_name    = local.merged_config.cluster_name
  cluster_version = local.merged_config.cluster_version

  # Use VPC config from common.local.hcl if provided, otherwise read from the
  # control-plane networking unit. Set vpc_id and private_subnet_ids in
  # common.local.hcl to deploy into a different VPC.
  vpc_id             = local.user_vpc_id != null ? local.user_vpc_id : dependency.vpc.outputs.vpc_id
  private_subnet_ids = local.user_private_subnet_ids != null ? local.user_private_subnet_ids : values(dependency.vpc.outputs.private_subnet_ids)

  cluster_role_name = local.merged_config.cluster_role_name
  node_role_name    = local.merged_config.node_role_name
  cluster_sg_name   = local.merged_config.cluster_sg_name
  node_sg_name      = local.merged_config.node_sg_name
  kms_key_alias     = local.merged_config.kms_key_alias

  jump_security_group_id = local.user_jump_sg_id != null ? local.user_jump_sg_id : try(dependency.jump.outputs.security_group_id, null)

  addon_versions          = local.merged_config.addon_versions
  cluster_access_mode     = local.merged_config.cluster_access_mode
  public_access_cidrs     = local.merged_config.public_access_cidrs
  cluster_admin_role_arns = local.merged_config.cluster_admin_role_arns
  log_retention_days      = local.merged_config.log_retention_days
  enable_irsa             = local.merged_config.enable_irsa

  # subnet_ids is injected into each node group from the resolved private subnets.
  # Node groups in common.local.hcl can set subnet_ids explicitly to pin to
  # specific AZs; an empty list falls back to all private subnets.
  node_groups = {
    for k, ng in local.merged_config.node_groups : k => merge(ng, {
      subnet_ids = length(ng.subnet_ids) > 0 ? ng.subnet_ids : (
        local.user_private_subnet_ids != null ? local.user_private_subnet_ids : values(dependency.vpc.outputs.private_subnet_ids)
      )
    })
  }
}
