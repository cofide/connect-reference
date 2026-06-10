# Control Plane Infrastructure

Terragrunt stack that provisions the AWS infrastructure for the Connect control plane. The SPIRE server must be running before the Connect infrastructure can be applied — see [SPIRE infrastructure](#spire-infrastructure) below.

See [cost.md](cost.md) for estimated monthly running costs.

## Configuration

### Root configuration

Create the root `common.local.hcl` before running any unit:

```sh
cp common.local.hcl.example common.local.hcl
```

Edit it to set your AWS account, region, and S3 remote state bucket:

```hcl
locals {
  aws_account_id         = "123456789012"
  aws_region             = "eu-west-2"
  tf_state_bucket_region = "eu-west-2"
  tf_state_bucket_name   = "my-tf-state-bucket"
  tf_state_key_prefix    = "connect-control-plane"
}
```

The S3 bucket must already exist. Remote state uses the native S3 lock file backend (`use_lockfile = true`) — no DynamoDB table is required.

### Per-unit configuration

Each unit directory contains a `common.local.hcl.example` documenting the available configuration. Copy it to `common.local.hcl` in that directory and edit it before applying the unit. Some values are required with no default (for example `cluster_admin_role_arns` in the cluster unit, or `bundle_domain` in `connect/bundle-distribution`). Others are optional overrides of the defaults — for example changing the VPC CIDR, switching to a larger RDS instance class, or enabling multi-AZ. Units that depend on other units in the stack can also have their dependency outputs overridden here, which is how you substitute existing infrastructure.

Units read their local config and merge it with the defaults defined in `terragrunt.hcl`. Any value present in `common.local.hcl` takes precedence over both the default and the corresponding dependency output.

### IAM mode

Each IAM unit (`eks-cluster/controllers/*`, `spire-server/iam-role`) supports two authentication modes, configured via `iam_mode` in the unit's `common.local.hcl`:

- **`pod_identity`** (default) — EKS Pod Identity. Requires the `eks-pod-identity-agent` add-on, which is enabled by default in the cluster unit.
- **`irsa`** — IAM Roles for Service Accounts. Requires `enable_irsa = true` in the cluster unit's `common.local.hcl` and `oidc_provider_arn` set in the controller unit's `common.local.hcl`.

---

## Deployment

Before running any Terragrunt command, create and populate the root configuration file:

```sh
cp common.local.hcl.example common.local.hcl
# Set aws_account_id, aws_region, tf_state_bucket_region, tf_state_bucket_name, tf_state_key_prefix
```

The S3 state bucket must already exist. See [Configuration](#configuration) for the full list of fields.

### SPIRE infrastructure

Creates the IAM role and PostgreSQL database for the SPIRE server. See [`spire-server/README.md`](spire-server/README.md) for the full steps.

**Existing RDS instance?** Set these values in the relevant unit's `common.local.hcl`. Your RDS instance must have IAM database authentication enabled and a PostgreSQL role with `rds_iam` and superuser privileges.

`spire-server/database/common.local.hcl` — to connect directly to RDS without an SSM tunnel:
```hcl
locals {
  aws_rds_iam_auth  = true
  db_host           = "my-db.xxxx.eu-west-2.rds.amazonaws.com"
  db_admin_username = "iam_admin"
}
```

If your RDS is only reachable through a bastion or SSM tunnel on `localhost:5432`, use `db_actual_host` instead (omit `aws_rds_iam_auth`):
```hcl
locals {
  db_actual_host    = "my-db.xxxx.eu-west-2.rds.amazonaws.com"
  db_admin_username = "iam_admin"
}
```

**Existing EKS cluster?** Set these values in `spire-server/iam-role/common.local.hcl`:
```hcl
locals {
  cluster_name   = "my-cluster"
  db_resource_id = "db-XXXXXXXXXXXXXXXXXXXX"  # RDS console → Configuration → DB resource ID
}
```

```sh
cd spire-server/database && terragrunt apply
cd spire-server/iam-role && terragrunt apply
```

**After applying, deploy the SPIRE server onto Kubernetes before continuing.** Follow the [k8s guide](../../k8s/README.md) and confirm the SPIRE OIDC discovery endpoint is publicly reachable before applying the Connect infrastructure.

### Connect infrastructure

Creates the S3 trust bundle bucket, CloudFront distribution, IAM role, and PostgreSQL database for the Connect API. See [`connect/README.md`](connect/README.md) for the full steps.

**Existing RDS instance?** Set the same connection values as above in `connect/database/common.local.hcl`.

**Existing DNS zone in Route53?** Set these in `connect/bundle-distribution/common.local.hcl`:
```hcl
locals {
  bundle_domain  = "bundles.example.com"
  hosted_zone_id = "Z0YOURHOSTEDZONEID"
}
```

If your DNS is managed outside Route53, skip `connect/bundle-distribution/` entirely and serve the trust bundle bucket via your own CDN — see [Alternative trust bundle exposure](connect/README.md#alternative-trust-bundle-exposure).

`connect/iam-role/common.local.hcl` always requires these two values (they cannot be derived from Terragrunt outputs); set `db_resource_id` only when bringing your own RDS:
```hcl
locals {
  spire_oidc_domain = "oidc-discovery.example.com"  # must match the SPIRE Helm values
  spiffe_id         = "spiffe://<trust-domain>/ns/connect/sa/cofide-connect-api"
  db_resource_id    = "db-XXXXXXXXXXXXXXXXXXXX"  # only if bringing your own RDS
}
```

`connect/bundle-bucket/common.local.hcl` always requires a bucket name (S3 names are globally unique):
```hcl
locals {
  bucket_name = "my-org-connect-bundles"
}
```

```sh
cd connect/bundle-bucket && terragrunt apply
cd connect/bundle-distribution && terragrunt apply  # skip if using alternative CDN
cd connect/database && terragrunt apply
cd connect/iam-role && terragrunt apply
```

---

### Reference base infrastructure

*(Skip this section if you have an existing VPC, EKS cluster, and RDS instance.)*

The following units provide a reference implementation for each base infrastructure component. Apply them before the SPIRE and Connect infrastructure above.

#### Base networking

`vpc` and `dns` have no dependencies and can be applied in parallel. `jump` requires `vpc`.

```sh
cd base/vpc && terragrunt apply
cd base/dns && terragrunt apply
cd base/jump && terragrunt apply
```

#### EKS cluster

The cluster unit creates the EKS control plane, node group, and add-ons. The three controller units only create IAM roles and Pod Identity Associations — the actual controllers are deployed onto Kubernetes in the next step.

```sh
cd base/eks-cluster/cluster
cp common.local.hcl.example common.local.hcl
# Set cluster_admin_role_arns to your IAM role ARN.
terragrunt apply
```

The controller units can be applied in parallel after the cluster:

```sh
cd base/eks-cluster/controllers/aws-load-balancer-controller && terragrunt apply
cd base/eks-cluster/controllers/cert-manager && terragrunt apply
cd base/eks-cluster/controllers/external-dns && terragrunt apply
```

See [`base/eks-cluster/cluster/README.md`](base/eks-cluster/cluster/README.md) for how to access the cluster.

#### Database

`rds-instance` depends on the cluster unit (it adds an egress rule to the EKS node security group) and must be applied after the cluster. `iam-admin` must follow `rds-instance`.

```sh
cd base/database/rds-instance && terragrunt apply
cd base/database/iam-admin && terragrunt apply
```

See [Database initialisation order](#database-initialisation-order) for why `iam-admin` must be applied before any unit that creates a PostgreSQL role, and [`base/database/rds-instance/README.md`](base/database/rds-instance/README.md) for how to access the instance.

---

## Database initialisation order

*(This section applies to from-scratch deployments using the reference `base/database/` units. If you have an existing RDS instance with an admin role that has `rds_iam` and superuser privileges, skip to `spire-server/database/` and `connect/database/`.)*

Three units manage the database layer and must be applied in order:

1. **`base/database/rds-instance/`** — provisions the RDS instance.
2. **`base/database/iam-admin/`** — connects as the RDS master user and creates an `iam_admin` PostgreSQL role with `rds_superuser` and `rds_iam`. **This must be applied before any unit that grants `rds_iam` to a database user.** Granting `rds_iam` triggers a `pg_hba.conf` reload that switches all SSL connections to IAM token authentication — after this point the master password can no longer be used over SSL. Subsequent applies of `iam-admin` itself use the `aws rds generate-db-auth-token` path; set `db_actual_host` in the unit's `common.local.hcl` to enable this.
3. **`spire-server/database/`** and **`connect/database/`** — connect as `iam_admin` using IAM tokens and create the `spire` and `connect` databases and roles.

The SSM tunnel to the database must be open (see [`base/database/rds-instance/README.md`](base/database/rds-instance/README.md)) when applying units 2 and 3. The IAM identity running Terragrunt must have `rds-db:connect` permission for the `iam_admin` user.
