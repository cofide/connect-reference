# SPIRE Server Infrastructure

Terraform units that provision the AWS resources needed by the SPIRE server and agent on the trust zone workload cluster. Apply these after the cluster unit and before deploying the SPIRE server onto Kubernetes.

## Units

### `iam-role/`

Creates the IAM role for the SPIRE server with KMS key manager permissions scoped to the SPIRE key alias prefix. The trust zone SPIRE server uses Connect as its datastore rather than RDS, so no `rds-db:connect` permission is needed.

SPIRE's default key policy grants `kms:*` directly to the SPIRE server role on every key it creates, so `kms:DescribeKey`, `kms:GetPublicKey`, `kms:ScheduleKeyDeletion`, and `kms:Sign` don't need to appear in the IAM role policy.

```sh
cd spire-server/iam-role && terragrunt apply
```

See `common.local.hcl.example` for available configuration overrides, including switching between Pod Identity and IRSA.

### `agent-iam-role/`

Creates the IAM role for the SPIRE agent with Secrets Manager permissions for the `aws_secretsmanager` SVIDStore plugin. The plugin tags every secret it manages with `spire-svid=true`; the policy uses that tag as a condition on all statements rather than a name prefix. `CreateSecret` requires the tag in the request; `DescribeSecret` uses `StringEqualsIfExists` so the plugin can check secret existence before creating; all other operations (`DeleteSecret`, `PutSecretValue`, `RestoreSecret`, `TagResource`) require the tag on the resource.

```sh
cd spire-server/agent-iam-role && terragrunt apply
```

See `common.local.hcl.example` for available configuration overrides, including switching between Pod Identity and IRSA.
