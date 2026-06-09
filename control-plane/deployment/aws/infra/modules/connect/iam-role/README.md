<!-- BEGIN_TF_DOCS -->
# connect/iam-role

Creates an IAM role for the Connect API that authenticates using SPIFFE JWT SVIDs
issued by the SPIRE server. The role grants RDS IAM authentication for the Connect
database user and S3 write access to the trust bundle bucket. Registers the SPIRE
OIDC discovery endpoint as an AWS IAM identity provider — the endpoint must be live
and reachable at apply time.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | ~> 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_openid_connect_provider.spire](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.connect_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [tls_certificate.spire_oidc](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bundle_bucket_arn"></a> [bundle\_bucket\_arn](#input\_bundle\_bucket\_arn) | ARN of the trust bundle S3 bucket. When set, grants s3:PutObject, s3:PutObjectTagging, s3:DeleteObject, and s3:ListBucket. When null, no S3 policy is attached. | `string` | `null` | no |
| <a name="input_bundle_bucket_kms_key_arn"></a> [bundle\_bucket\_kms\_key\_arn](#input\_bundle\_bucket\_kms\_key\_arn) | ARN of the KMS key used to encrypt the trust bundle bucket. When set, grants kms:GenerateDataKey. Required alongside bundle\_bucket\_arn when the bucket uses SSE-KMS. | `string` | `null` | no |
| <a name="input_db_resource_id"></a> [db\_resource\_id](#input\_db\_resource\_id) | RDS DbiResourceId for the Connect API database instance. When set alongside db\_username, grants rds-db:connect for IAM authentication. When null, no RDS policy is attached. | `string` | `null` | no |
| <a name="input_db_username"></a> [db\_username](#input\_db\_username) | PostgreSQL role name for the Connect API. Used to construct the rds-db:connect IAM resource ARN. | `string` | `null` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Name of the IAM role for the Connect API. | `string` | n/a | yes |
| <a name="input_spiffe_id"></a> [spiffe\_id](#input\_spiffe\_id) | SPIFFE ID of the Connect API workload (e.g. spiffe://trust-domain/ns/connect/sa/connect-api). Used as the sub condition in the IAM role trust policy to restrict JWT SVID exchange to this specific workload identity. | `string` | n/a | yes |
| <a name="input_spire_oidc_domain"></a> [spire\_oidc\_domain](#input\_spire\_oidc\_domain) | Full domain of the SPIRE server OIDC discovery endpoint (e.g. oidc.connect.example.com). Used to register the IAM OIDC provider and construct trust policy conditions. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the Connect API IAM role. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of the Connect API IAM role. |
<!-- END_TF_DOCS -->