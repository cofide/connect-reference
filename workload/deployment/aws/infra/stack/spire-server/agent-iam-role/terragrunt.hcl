include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "cluster" {
  config_path = "../../eks-cluster/cluster"

  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    cluster_name      = "mock-cluster"
    oidc_provider_arn = "arn:aws:iam::012345678901:oidc-provider/oidc.eks.eu-west-2.amazonaws.com/id/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
  }
}

locals {
  default_config = {
    role_name            = "cofide-connect-trust-zone-aws-reference-arch-spire-agent"
    iam_mode             = "pod_identity"
    namespace            = "spire-system"
    service_account_name = "spire-agent"
  }

  unit_config_path = "${get_terragrunt_dir()}/common.local.hcl"
  has_local_config = fileexists(local.unit_config_path)
  user_config      = local.has_local_config ? read_terragrunt_config(local.unit_config_path).locals : {}
  merged_config    = merge(local.default_config, local.user_config)

  user_cluster_name      = try(local.merged_config.cluster_name, null)
  user_oidc_provider_arn = try(local.merged_config.oidc_provider_arn, null)
}

terraform {
  source = "${get_repo_root()}//control-plane/deployment/aws/infra/modules/spire/agent-iam-role"
}

inputs = {
  role_name            = local.merged_config.role_name
  iam_mode             = local.merged_config.iam_mode
  namespace            = local.merged_config.namespace
  service_account_name = local.merged_config.service_account_name

  cluster_name      = local.user_cluster_name != null ? local.user_cluster_name : try(dependency.cluster.outputs.cluster_name, null)
  oidc_provider_arn = local.user_oidc_provider_arn != null ? local.user_oidc_provider_arn : try(dependency.cluster.outputs.oidc_provider_arn, null)
}
