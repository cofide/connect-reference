# Trust Zone Infrastructure

Terragrunt stack that provisions the AWS infrastructure for a Cofide Connect trust zone workload cluster. The SPIRE server is deployed onto this cluster and registered as a trust zone with the Connect control plane.

The stack reuses the VPC, jump instance, and Route53 hosted zone from the control-plane stack by default. Cross-stack dependencies are optional — set the relevant values in a unit's `common.local.hcl` to deploy against different infrastructure.

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
  tf_state_key_prefix    = "connect-trust-zone"
}
```

Use a different `tf_state_key_prefix` from the control-plane stack to avoid state key collisions.

### Per-unit configuration

Each unit directory contains a `common.local.hcl.example` documenting the available configuration. Copy it to `common.local.hcl` and edit it before applying. At minimum, set `cluster_admin_role_arns` in `eks-cluster/cluster/common.local.hcl`.

### IAM mode

The `spire-server/iam-role` unit supports two authentication modes, configured via `iam_mode` in `common.local.hcl`:

- **`pod_identity`** (default) — EKS Pod Identity. Requires the `eks-pod-identity-agent` add-on, which is enabled by default in the cluster unit.
- **`irsa`** — IAM Roles for Service Accounts. Requires `enable_irsa = true` in the cluster unit's `common.local.hcl` and `oidc_provider_arn` set in the controller unit's `common.local.hcl`.

---

## Deployment

Before running any Terragrunt command, create and populate the root configuration file:

```sh
cp common.local.hcl.example common.local.hcl
# Set aws_account_id, aws_region, tf_state_bucket_region, tf_state_bucket_name, tf_state_key_prefix
```

### EKS cluster

The cluster unit creates the EKS control plane, node group, and add-ons. Apply it first; the controller and SPIRE units depend on its outputs.

```sh
cd eks-cluster/cluster
cp common.local.hcl.example common.local.hcl
# Set cluster_admin_role_arns to your IAM role ARN.
terragrunt apply
```

See [`eks-cluster/cluster/README.md`](eks-cluster/cluster/README.md) for how to access the cluster.

### SPIRE server IAM role

Creates the IAM role for the SPIRE server with KMS permissions. Apply this after the cluster unit. See [`spire-server/README.md`](spire-server/README.md) for details.

```sh
cd spire-server/iam-role && terragrunt apply
```

### Connect registration

Registers the trust zone, cluster, and trust zone server with Cofide Connect in a single apply. See [`connect/README.md`](connect/README.md) for details.

```sh
export COFIDE_API_TOKEN="<your-api-token>"

cd connect/trust-zone
cp common.local.hcl.example common.local.hcl
# Set trust_domain.
terragrunt apply
```

Once applied, run `generate-local-values.sh` in `k8s/spire-server/spire/` to populate the SPIRE server configuration — see the [k8s guide](../../k8s/README.md).
