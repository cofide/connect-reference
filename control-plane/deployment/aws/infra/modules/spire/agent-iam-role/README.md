<!-- BEGIN_TF_DOCS -->
# spire/agent-iam-role

Creates an IAM role for the SPIRE agent with AWS Secrets Manager permissions for
the aws\_secretsmanager SVIDStore plugin. The plugin stores workload SVIDs as secrets
in Secrets Manager; the agent needs create, update, describe, and delete permissions
on secrets under the configured name prefix.

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
| [aws_eks_pod_identity_association.spire_agent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_iam_role.spire_agent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.secretsmanager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.secretsmanager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name. Required for Pod Identity association. | `string` | `null` | no |
| <a name="input_iam_mode"></a> [iam\_mode](#input\_iam\_mode) | IAM binding mode. 'pod\_identity' uses EKS Pod Identity (requires eks-pod-identity-agent add-on). 'irsa' uses IAM Roles for Service Accounts (requires enable\_irsa = true in the cluster unit and oidc\_provider\_arn to be set). | `string` | `"pod_identity"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace the SPIRE agent runs in. Used for the Pod Identity association and IRSA trust condition. | `string` | `"spire-system"` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | ARN of the EKS cluster OIDC provider. Required for IRSA mode. | `string` | `null` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Name for the SPIRE agent IAM role. | `string` | n/a | yes |
| <a name="input_service_account_name"></a> [service\_account\_name](#input\_service\_account\_name) | Kubernetes service account name for the SPIRE agent. Used for the Pod Identity association and IRSA trust condition. | `string` | `"spire-agent"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the SPIRE agent IAM role. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the SPIRE agent IAM role. |
<!-- END_TF_DOCS -->