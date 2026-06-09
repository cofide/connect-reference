<!-- BEGIN_TF_DOCS -->
# rds-instance

Creates a PostgreSQL RDS instance in intra subnets (no public endpoint) with
KMS-encrypted storage, IAM database authentication enabled, and the master password
managed by Secrets Manager. Accepts a map of security groups to create ingress
rules from, allowing fine-grained access control without coupling the module to
specific callers.

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
| [aws_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_iam_role.rds_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.rds_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.rds_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_alias.rds_storage](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.rds_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key.rds_storage](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_security_group.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_ingress_rule.rds_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_iam_policy_document.rds_monitoring_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allocated_storage"></a> [allocated\_storage](#input\_allocated\_storage) | Initial allocated storage in GiB. | `number` | `20` | no |
| <a name="input_backup_retention_period"></a> [backup\_retention\_period](#input\_backup\_retention\_period) | Number of days to retain automated backups. Minimum 1 to keep backups enabled. Production deployments should set 7 or higher. | `number` | `1` | no |
| <a name="input_backup_window"></a> [backup\_window](#input\_backup\_window) | Preferred daily UTC window for automated backups. Must not overlap with maintenance\_window. | `string` | `"03:00-04:00"` | no |
| <a name="input_db_identifier"></a> [db\_identifier](#input\_db\_identifier) | RDS DB instance identifier. | `string` | n/a | yes |
| <a name="input_db_instance_class"></a> [db\_instance\_class](#input\_db\_instance\_class) | RDS instance class. | `string` | `"db.t3.medium"` | no |
| <a name="input_db_username"></a> [db\_username](#input\_db\_username) | Master username for the RDS instance. | `string` | `"postgres"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Whether to enable deletion protection on the RDS instance. Set to true for production deployments. | `bool` | `false` | no |
| <a name="input_enabled_cloudwatch_logs_exports"></a> [enabled\_cloudwatch\_logs\_exports](#input\_enabled\_cloudwatch\_logs\_exports) | PostgreSQL log types to export to CloudWatch. Production deployments should set ["postgresql", "upgrade"]. | `list(string)` | `[]` | no |
| <a name="input_final_snapshot_identifier"></a> [final\_snapshot\_identifier](#input\_final\_snapshot\_identifier) | Identifier for the final snapshot when skip\_final\_snapshot is false. Required when skip\_final\_snapshot = false. | `string` | `null` | no |
| <a name="input_ingress_security_groups"></a> [ingress\_security\_groups](#input\_ingress\_security\_groups) | Security groups permitted to connect to the RDS instance on port 5432. Map key is used as the Terraform resource key. | <pre>map(object({<br/>    security_group_id = string<br/>    description       = string<br/>  }))</pre> | `{}` | no |
| <a name="input_kms_key_alias"></a> [kms\_key\_alias](#input\_kms\_key\_alias) | Alias for the KMS key used for RDS storage encryption. Must begin with 'alias/'. | `string` | n/a | yes |
| <a name="input_maintenance_window"></a> [maintenance\_window](#input\_maintenance\_window) | Preferred weekly UTC window for maintenance. Must not overlap with backup\_window. | `string` | `"mon:04:00-mon:05:00"` | no |
| <a name="input_max_allocated_storage"></a> [max\_allocated\_storage](#input\_max\_allocated\_storage) | Maximum storage in GiB for autoscaling. Must be greater than allocated\_storage. Production deployments should set a higher ceiling. | `number` | `100` | no |
| <a name="input_monitoring_interval"></a> [monitoring\_interval](#input\_monitoring\_interval) | Interval in seconds for enhanced monitoring metrics. 0 disables enhanced monitoring. Production deployments should set 60. | `number` | `0` | no |
| <a name="input_monitoring_role_name"></a> [monitoring\_role\_name](#input\_monitoring\_role\_name) | Name of the IAM role for RDS enhanced monitoring. Required when monitoring\_interval > 0. | `string` | `null` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | Whether to enable Multi-AZ for the RDS instance. | `bool` | `false` | no |
| <a name="input_parameter_group_name"></a> [parameter\_group\_name](#input\_parameter\_group\_name) | Name for the RDS DB parameter group. | `string` | n/a | yes |
| <a name="input_performance_insights_enabled"></a> [performance\_insights\_enabled](#input\_performance\_insights\_enabled) | Whether to enable Performance Insights. Recommended for production deployments. Free for 7-day retention; longer retention incurs cost. | `bool` | `false` | no |
| <a name="input_performance_insights_retention_period"></a> [performance\_insights\_retention\_period](#input\_performance\_insights\_retention\_period) | Retention period in days for Performance Insights data. 7 days is free; production deployments should use 731 days for long-term analysis. | `number` | `7` | no |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL engine version. | `string` | `"17"` | no |
| <a name="input_secret_kms_key_alias"></a> [secret\_kms\_key\_alias](#input\_secret\_kms\_key\_alias) | Alias for the KMS key used to encrypt the RDS master user secret in Secrets Manager. Must begin with 'alias/'. | `string` | n/a | yes |
| <a name="input_security_group_name"></a> [security\_group\_name](#input\_security\_group\_name) | Name for the RDS security group. | `string` | n/a | yes |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Whether to skip the final snapshot on deletion. Set to false for production deployments and provide a final\_snapshot\_identifier. | `bool` | `true` | no |
| <a name="input_storage_type"></a> [storage\_type](#input\_storage\_type) | Storage type for the RDS instance. gp3 provides better price/performance than gp2. | `string` | `"gp3"` | no |
| <a name="input_subnet_group_name"></a> [subnet\_group\_name](#input\_subnet\_group\_name) | Name for the RDS DB subnet group. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of subnet IDs for the RDS subnet group. | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID in which to create the RDS security group. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_db_endpoint"></a> [db\_endpoint](#output\_db\_endpoint) | Connection endpoint for the RDS instance (host:port). |
| <a name="output_db_host"></a> [db\_host](#output\_db\_host) | Hostname of the RDS instance. |
| <a name="output_db_identifier"></a> [db\_identifier](#output\_db\_identifier) | RDS DB instance identifier. |
| <a name="output_db_port"></a> [db\_port](#output\_db\_port) | Port the RDS instance listens on. |
| <a name="output_db_resource_id"></a> [db\_resource\_id](#output\_db\_resource\_id) | RDS DbiResourceId — used to construct the rds-db:connect IAM permission ARN. |
| <a name="output_db_username"></a> [db\_username](#output\_db\_username) | Master username for the RDS instance. |
<!-- END_TF_DOCS -->