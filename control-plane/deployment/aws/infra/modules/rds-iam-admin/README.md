<!-- BEGIN_TF_DOCS -->
# rds-iam-admin

Creates a PostgreSQL role with `rds_superuser` and `rds_iam` for ongoing database
administration using IAM token authentication. This role must be created before any
other role is granted `rds_iam` — granting `rds_iam` triggers a pg\_hba.conf reload
that makes password-based authentication unavailable over SSL.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_postgresql"></a> [postgresql](#requirement\_postgresql) | ~> 1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_postgresql"></a> [postgresql](#provider\_postgresql) | ~> 1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [postgresql_grant_role.iam_admin_rds_iam](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/grant_role) | resource |
| [postgresql_grant_role.iam_admin_superuser](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/grant_role) | resource |
| [postgresql_role.iam_admin](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/role) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_iam_admin_username"></a> [iam\_admin\_username](#input\_iam\_admin\_username) | Name of the IAM admin database role to create. This role is used for all subsequent database administration after this unit is applied. | `string` | `"iam_admin"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_iam_admin_username"></a> [iam\_admin\_username](#output\_iam\_admin\_username) | Username of the IAM admin database role. Used by subsequent database units to connect via IAM token authentication. |
<!-- END_TF_DOCS -->