# SPIRE Server Infrastructure

Terraform units that provision the AWS resources needed by the SPIRE server. Apply these after `base/database/iam-admin/` and before deploying the SPIRE server onto Kubernetes.

## Units

### `database/`

Creates the `spire` PostgreSQL database and role, connecting to the RDS instance as `iam_admin` using IAM token authentication.

The SSM database tunnel must be open (see [`../base/database/rds-instance/README.md`](../base/database/rds-instance/README.md)) and the IAM identity running Terragrunt must have `rds-db:connect` permission for `iam_admin`.

```sh
cd spire-server/database && terragrunt apply
```

### `iam-role/`

Creates the IAM role for the SPIRE server with RDS IAM authentication permission for the `spire` database user and KMS key manager permissions scoped to the SPIRE key alias prefix.

SPIRE's default key policy grants `kms:*` directly to the SPIRE server role on every key it creates, so `kms:DescribeKey`, `kms:GetPublicKey`, `kms:ScheduleKeyDeletion`, and `kms:Sign` don't need to appear in the IAM role policy.

```sh
cd spire-server/iam-role && terragrunt apply
```

See each unit's `common.local.hcl.example` for available configuration overrides, including switching between Pod Identity and IRSA.
