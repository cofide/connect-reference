# SPIRE Server

Deploys the SPIRE server onto the EKS cluster. The Kubernetes controllers in [`controllers/`](../controllers/README.md) must be installed first.

## SPIRE CRDs

Install the CRDs before the SPIRE server chart:

```sh
cd spire-server/spire-crds
./install.sh
```

## SPIRE server

```sh
cd spire-server/spire
cp values.local.yaml.example values.local.yaml
# Fill in values — see the table below for where each comes from.
./install.sh
```

| Field in `values.local.yaml` | Where to get the value |
|------------------------------|------------------------|
| `global.spire.clusterName` | EKS cluster name |
| `global.spire.trustDomain` | Choose a trust domain (e.g. `connect.example.com`) |
| `global.spire.jwtIssuer` | `https://<oidc-subdomain>.<zone>` |
| `global.spire.caSubject.*` | Country code, org name, and common name for the upstream CA cert |
| `spiffe-oidc-discovery-provider.service.annotations` | The OIDC discovery hostname for ExternalDNS |
| `spiffe-oidc-discovery-provider.tls.certManager.certificate.dnsNames` | Same OIDC discovery hostname |
| `spire-server.dataStore.sql.region` | AWS region |
| `spire-server.dataStore.sql.host` | RDS instance endpoint |
| `spire-server.dataStore.sql.databaseName` | Output of `spire-server/database`: `spire_db_name` (default: `spire`) |
| `spire-server.dataStore.sql.username` | Output of `spire-server/database`: `spire_db_user` (default: `spire`) |
| `spire-server.keyManager.awsKMS.region` | AWS region |

The SPIRE server runs as a `Deployment` — each replica creates its own KMS key identified by its pod name via the Kubernetes Downward API, so no persistent storage is required.

If all base infra units (`base/eks-cluster/cluster`, `base/dns`, `base/database/rds-instance`) have been applied via this Terragrunt stack, you can generate `values.local.yaml` automatically instead:

```sh
./generate-local-values.sh <trust-domain> <oidc-subdomain> <ca-country> <ca-organization> <ca-common-name>
# e.g: ./generate-local-values.sh connect.example.com oidc-discovery GB "Example Ltd" "Example Ltd SPIRE Root CA"
```

## Confirm OIDC endpoint is reachable

Before proceeding, confirm the SPIRE OIDC discovery endpoint is publicly reachable:

```sh
curl https://<oidc-subdomain>.<zone>/.well-known/openid-configuration
```

This endpoint must respond before the Connect infrastructure can be applied — `connect/iam-role` creates `aws_iam_openid_connect_provider`, which fetches the TLS certificate from this URL at apply time.

**Return to [`infra/stack/README.md`](../infra/stack/README.md) and apply the Connect infrastructure before continuing.**
