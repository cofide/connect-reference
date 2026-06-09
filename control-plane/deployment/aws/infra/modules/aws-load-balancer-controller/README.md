<!-- BEGIN_TF_DOCS -->
# aws-load-balancer-controller

Creates an IAM role for the AWS Load Balancer Controller with the permissions
required to create and manage Network Load Balancers and Application Load Balancers
from Kubernetes Service and Ingress resources. Supports EKS Pod Identity (default)
or IRSA.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_pod_identity_association.aws_load_balancer_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_iam_policy.aws_load_balancer_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.aws_load_balancer_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.aws_load_balancer_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_openid_connect_provider.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS cluster to create the Pod Identity association in. Required for Pod Identity mode. | `string` | `null` | no |
| <a name="input_iam_mode"></a> [iam\_mode](#input\_iam\_mode) | IAM authentication mode for the AWS Load Balancer Controller. 'pod\_identity' uses EKS Pod Identity; 'irsa' uses IAM Roles for Service Accounts. | `string` | `"pod_identity"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace that the AWS Load Balancer Controller runs in | `string` | `"kube-system"` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of the IAM OIDC provider for the EKS cluster. Required when iam\_mode is 'irsa'. | `string` | `null` | no |
| <a name="input_policy_name"></a> [policy\_name](#input\_policy\_name) | Name of the IAM policy for the AWS Load Balancer Controller | `string` | n/a | yes |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Name of the IAM role for the AWS Load Balancer Controller | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Kubernetes service account name for the AWS Load Balancer Controller | `string` | `"aws-load-balancer-controller"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the IAM role for the AWS Load Balancer Controller |
<!-- END_TF_DOCS -->