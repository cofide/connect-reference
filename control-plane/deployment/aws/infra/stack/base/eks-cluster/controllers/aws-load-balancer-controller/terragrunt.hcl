include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "cluster" {
  config_path = "../../cluster"

  # Allow this dependency to be skipped when cluster_name is provided directly
  # in common.local.hcl (e.g. deploying against an existing cluster).
  mock_outputs_allowed_terraform_commands = ["apply", "destroy", "plan", "validate"]
  mock_outputs = {
    cluster_name      = "mock-cluster"
    oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/mock"
  }
}

locals {
  default_config = {
    role_name   = "cofide-connect-control-plane-aws-reference-arch-alb-controller"
    policy_name = "cofide-connect-control-plane-aws-reference-arch-alb-controller"

    iam_mode = "pod_identity"

    namespace            = "kube-system"
    service_account_name = "aws-load-balancer-controller"
  }

  unit_config_path = "${get_terragrunt_dir()}/common.local.hcl"
  has_local_config = fileexists(local.unit_config_path)
  user_config      = local.has_local_config ? read_terragrunt_config(local.unit_config_path).locals : {}
  merged_config    = merge(local.default_config, local.user_config)

  # Extracted from merged_config if set; null otherwise. The actual selection
  # between these and the cluster dependency outputs happens in inputs below.
  user_cluster_name      = try(local.merged_config.cluster_name, null)
  user_oidc_provider_arn = try(local.merged_config.oidc_provider_arn, null)
}

terraform {
  source = "${get_repo_root()}//control-plane/deployment/aws/infra/modules/aws-load-balancer-controller"
}

inputs = {
  cluster_name      = local.user_cluster_name != null ? local.user_cluster_name : dependency.cluster.outputs.cluster_name
  oidc_provider_arn = local.user_oidc_provider_arn != null ? local.user_oidc_provider_arn : try(dependency.cluster.outputs.oidc_provider_arn, null)

  role_name   = local.merged_config.role_name
  policy_name = local.merged_config.policy_name

  iam_mode = local.merged_config.iam_mode

  namespace            = local.merged_config.namespace
  service_account_name = local.merged_config.service_account_name
}
