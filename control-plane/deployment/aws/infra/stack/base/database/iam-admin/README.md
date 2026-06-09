# base/database/iam-admin

Terragrunt unit that creates an `iam_admin` PostgreSQL role with `rds_superuser` and `rds_iam`. This role is used by the `spire-server/database` and `connect/database` units to create databases and roles using IAM token authentication.

**This unit must be applied before any unit that grants `rds_iam` to any PostgreSQL user.** Granting `rds_iam` triggers a `pg_hba.conf` reload in RDS that switches all SSL connections to IAM token authentication — after this point the RDS master password can no longer be used over SSL.

An SSM tunnel to the database must be open on `localhost:5432` before applying this unit. See [`../rds-instance/README.md`](../rds-instance/README.md) for tunnel setup.

## First apply — Secrets Manager (master password)

On the first apply, the unit connects as the RDS master user using the password stored in Secrets Manager. No `common.local.hcl` changes are needed — the unit reads the instance identifier from the `rds-instance` dependency output.

```sh
cd base/database/iam-admin && terragrunt apply
```

## Subsequent applies — IAM token authentication

Once `rds_iam` has been granted, SSL connections require IAM token authentication. Set `db_actual_host` in `common.local.hcl` to switch the unit to IAM token mode:

```hcl
locals {
  db_actual_host = "my-db.abc123.eu-west-2.rds.amazonaws.com"
}
```

The unit generates a short-lived auth token using your IAM credentials and connects via the SSM tunnel as usual.
