# SPIRE Server Infrastructure

Terraform unit that provisions the AWS resources needed by the SPIRE server on the trust zone workload cluster. Apply this after the cluster unit and before deploying the SPIRE server onto Kubernetes.

## Units

### `iam-role/`

Creates the IAM role for the SPIRE server with KMS key manager permissions scoped to the SPIRE key alias prefix. The trust zone SPIRE server uses Connect as its datastore rather than RDS, so no `rds-db:connect` permission is needed.

SPIRE's default key policy grants `kms:*` directly to the SPIRE server role on every key it creates, so `kms:DescribeKey`, `kms:GetPublicKey`, `kms:ScheduleKeyDeletion`, and `kms:Sign` don't need to appear in the IAM role policy.

```sh
cd spire-server/iam-role && terragrunt apply
```

See `common.local.hcl.example` for available configuration overrides, including switching between Pod Identity and IRSA.
