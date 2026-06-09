<!-- BEGIN_TF_DOCS -->
# spire/database

Creates a PostgreSQL database and login role for the SPIRE server, with `rds_iam`
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
| [postgresql_database.spire](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/database) | resource |
| [postgresql_grant.spire_database](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/grant) | resource |
| [postgresql_grant.spire_public_schema](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/grant) | resource |
| [postgresql_grant_role.spire_rds_iam](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/grant_role) | resource |
| [postgresql_role.spire](https://registry.terraform.io/providers/cyrilgdn/postgresql/latest/docs/resources/role) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_spire_db_name"></a> [spire\_db\_name](#input\_spire\_db\_name) | Name of the database to create for the SPIRE server datastore. | `string` | `"spire"` | no |
| <a name="input_spire_db_user"></a> [spire\_db\_user](#input\_spire\_db\_user) | Name of the PostgreSQL role to create for the SPIRE server. Granted rds\_iam for IAM-only authentication — no password is set. | `string` | `"spire"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_spire_db_name"></a> [spire\_db\_name](#output\_spire\_db\_name) | Name of the SPIRE server database. |
| <a name="output_spire_db_user"></a> [spire\_db\_user](#output\_spire\_db\_user) | Name of the PostgreSQL role for the SPIRE server. Use in rds-db:connect IAM permissions and SPIRE datastore configuration. |
<!-- END_TF_DOCS -->