module "istio_multi_mesh" {
  source = "git::https://github.com/cofide/cofide-terraform-modules.git//modules/istio-multi-mesh?depth=1&ref=v0.8.0"

  aws_region                   = var.aws_region
  admin_access_role            = var.admin_access_role
  cluster_names                = var.cluster_names
  developer_access_role        = var.developer_access_role
  eks_node_group_capacity_type = var.eks_node_group_capacity_type
  oidc_provider_client_id      = var.oidc_provider_client_id
  oidc_provider_issuer_url     = var.oidc_provider_issuer_url
}
