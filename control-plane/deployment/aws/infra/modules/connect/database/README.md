<!-- BEGIN_TF_DOCS -->
# connect/database

Creates a PostgreSQL database and login role for the Connect API, with `rds_iam`
granted so the role authenticates via short-lived IAM tokens at runtime rather than
a static password. Requires an `iam_admin` role with `rds_superuser` to exist — see
the `rds-iam-admin` module.

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
| [postgresql_database.connect](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/database) | resource |
| [postgresql_grant.connect_api_database](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/grant) | resource |
| [postgresql_grant.connect_api_public_schema](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/grant) | resource |
| [postgresql_grant_role.connect_api_rds_iam](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/grant_role) | resource |
| [postgresql_role.connect_api](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/role) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_connect_db_name"></a> [connect\_db\_name](#input\_connect\_db\_name) | Name of the database to create for the Connect API datastore. | `string` | n/a | yes |
| <a name="input_connect_db_user"></a> [connect\_db\_user](#input\_connect\_db\_user) | Name of the PostgreSQL role to create for the Connect API. Granted rds\_iam for IAM-only authentication — no password is set. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_connect_db_name"></a> [connect\_db\_name](#output\_connect\_db\_name) | Name of the Connect API database. |
| <a name="output_connect_db_user"></a> [connect\_db\_user](#output\_connect\_db\_user) | Name of the PostgreSQL role for the Connect API. Use in rds-db:connect IAM permissions and Connect API datastore configuration. |
<!-- END_TF_DOCS -->