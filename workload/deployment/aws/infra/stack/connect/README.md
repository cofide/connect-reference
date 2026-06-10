# Connect Registration

Terragrunt unit that registers the trust zone and cluster with Cofide Connect using the [`cofide/cofide`](https://registry.terraform.io/providers/cofide/cofide/latest/docs) Terraform provider.

This unit is applied after the AWS infrastructure is provisioned and before deploying the SPIRE server onto Kubernetes. The IDs and PSAT configuration it outputs are used to populate the SPIRE server's datastore configuration.

## Prerequisites

- `COFIDE_API_TOKEN` — API token for the Connect API; must be set as an environment variable.
- The control-plane `base/dns` unit must be applied — the Connect gRPC address (`<zone>:443`) is derived from its `zone_name` output. The provider prepends the `connect.` subdomain automatically. Set `connect_url` in `common.local.hcl` to override (format: `host:port`, no scheme).
- The `eks-cluster/cluster` unit must be applied — the OIDC issuer URL is read from its outputs. Set `oidc_issuer_url` in `common.local.hcl` to override.

## `trust-zone/`

Registers a trust zone and cluster with Cofide Connect. The cluster is registered in the same apply as the trust zone because the SPIRE server for this trust zone lives on this cluster.

**Required values in `common.local.hcl`:**

| Local | Description |
|-------|-------------|
| `trust_domain` | SPIFFE trust domain for the trust zone (e.g. `trust-zone.example.cofide.dev`) |

**Outputs:**

| Name | Description |
|------|-------------|
| `trust_zone_id` | Trust zone ID — used in the SPIRE server datastore config |
| `cluster_id` | Cluster ID — used in the SPIRE server datastore config |
| `bundle_endpoint_url` | Bundle endpoint URL assigned by Connect |

## Deployment

```sh
export COFIDE_API_TOKEN="<your-api-token>"

cd trust-zone
cp common.local.hcl.example common.local.hcl
# Set trust_domain.
terragrunt apply
```

Once applied, run `generate-local-values.sh` in `k8s/spire-server/spire/` to populate the SPIRE server configuration — see the [k8s guide](../../../k8s/README.md).
