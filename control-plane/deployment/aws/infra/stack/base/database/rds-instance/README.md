# rds-instance

Terragrunt unit that provisions the shared PostgreSQL RDS instance for the Connect control plane. Creates:

- RDS PostgreSQL instance in intra subnets (no public endpoint)
- Subnet group and security group
- KMS key for storage encryption
- KMS key for the Secrets Manager secret holding the master password
- Ingress rules on the RDS security group from the EKS node and jump instance security groups
- Egress rules on the EKS node and jump instance security groups to reach the RDS port

The `iam-admin`, `spire-server/database`, and `connect/database` units all depend on this unit.

## Configuration

Copy `common.local.hcl.example` to `common.local.hcl` to override defaults. All fields are optional — the defaults match the reference deployment naming.

For production use, consider setting:

```hcl
locals {
  multi_az                = true
  backup_retention_period = 7
  skip_final_snapshot     = false
  deletion_protection     = true
  performance_insights_enabled = true
}
```

## Database Access

The RDS instance is deployed in intra subnets with no public endpoint. Access from developer machines is via SSM port forwarding through the jump instance — no public IPs, no open inbound ports, no SSH keys.

### Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with credentials for the target account
- [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) for the AWS CLI
- `psql` (PostgreSQL client)
- Jump instance deployed (`base/jump/` unit applied)

Retrieve the Terraform outputs you will need:

```sh
DB_HOST=$(terragrunt output -raw db_host)
DB_PORT=$(terragrunt output -raw db_port)
DB_USERNAME=$(terragrunt output -raw db_username)
DB_RESOURCE_ID=$(terragrunt output -raw db_resource_id)
JUMP_INSTANCE_ID=$(cd ../../jump && terragrunt output -raw instance_id)
```

### Opening an SSM tunnel to the database

Each session requires an active SSM tunnel. Open a dedicated terminal and run:

```sh
aws ssm start-session \
  --target "$JUMP_INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"$DB_HOST\"],\"portNumber\":[\"$DB_PORT\"],\"localPortNumber\":[\"5432\"]}" \
  --region <region>
```

Leave this running. Database connections to `localhost:5432` will be forwarded to the RDS instance. Close the tunnel terminal when done.

### Connecting as the master user

The master password is managed by AWS Secrets Manager (`manage_master_user_password = true`). Retrieve it before connecting:

```sh
SECRET_ARN=$(aws rds describe-db-instances \
  --db-instance-identifier <db-identifier> \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' \
  --output text \
  --region <region>)

DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query 'SecretString' \
  --output text \
  --region <region> | jq -r '.password')
```

Connect with psql (tunnel must be open):

```sh
psql "host=localhost port=5432 dbname=postgres user=$DB_USERNAME password=$DB_PASSWORD sslmode=require"
```

### Connecting with IAM authentication

IAM database authentication is enabled (`iam_database_authentication_enabled = true`). Instead of a password, a short-lived auth token is generated using your IAM credentials. The IAM principal must have `rds-db:connect` permission for the target database user.

The required IAM permission ARN has the form:

```
arn:aws:rds-db:<region>:<account-id>:dbuser:<db-resource-id>/<db-username>
```

Where `<db-resource-id>` is the value of the `db_resource_id` output (e.g. `db-ABCDEFGHIJKLMNOPQRSTUVWXYZ`).

Generate an auth token and connect (tunnel must be open):

```sh
DB_AUTH_TOKEN=$(aws rds generate-db-auth-token \
  --hostname "$DB_HOST" \
  --port "$DB_PORT" \
  --username <iam-db-username> \
  --region <region>)

psql "host=localhost port=5432 dbname=<database> user=<iam-db-username> password=$DB_AUTH_TOKEN sslmode=require"
```

SSL is required for IAM authentication — connections without `sslmode=require` (or stronger) will be rejected by the database.

Auth tokens are valid for 15 minutes. Generate a new one if the connection is rejected with an authentication error.
