# Connect API and Connect UI

Deploys the Connect API and Connect UI onto the EKS cluster. The Connect infrastructure in `infra/stack/connect/` must be applied before starting here.

## Namespace

Create the `connect` namespace before applying certificates or installing charts:

```sh
cd connect/namespace
./apply.sh
```

## Certificates

The Connect API and Connect UI each use an envoy sidecar for TLS termination. cert-manager Certificate resources must be applied before the Helm charts so TLS secrets are present when the sidecars start.

```sh
# Connect API certificate
cd connect/connect-api/certificate
cp certificate.local.yaml.example certificate.local.yaml
# Set the three dnsNames to connect.<zone>, connect-agent.<zone>, and xds.<zone>
./apply.sh

# Connect UI certificate
cd connect/connect-ui/certificate
cp certificate.local.yaml.example certificate.local.yaml
# Set the dnsName to <ui-subdomain>.<zone>
./apply.sh
```

If the `base/dns` Terragrunt unit has been applied, the certificate local files can be generated automatically instead:

```sh
./generate-certificate-local.sh          # Connect API
./generate-certificate-local.sh <ui-subdomain>  # Connect UI
```

Wait for both certificates to be issued before installing the Helm charts:

```sh
kubectl get certificate -n connect --watch
```

## Connect API

```sh
cd connect/connect-api
cp values.local.yaml.example values.local.yaml
# Fill in values — see the table below for where each comes from.
./install.sh
```

| Field in `values.local.yaml` | Where to get the value |
|------------------------------|------------------------|
| `service.annotations` (ExternalDNS hostnames) | `connect.<zone>`, `connect-agent.<zone>`, `xds.<zone>` |
| `connect.urlBase` | Route53 zone name (e.g. `example.com`) |
| `connect.allowedOrigins` | `https://<ui-subdomain>.<zone>` |
| `connect.trustDomain` | Trust domain from the deployed `spire` Helm release |
| `connect.connectTrustBundleStoreURL` | Output of `connect/bundle-distribution`: `distribution_domain_name` — prefix with `https://` |
| `connect.datastore.rds.host` | RDS instance endpoint |
| `connect.datastore.rds.databaseName` | Output of `connect/database`: `connect_db_name` (default: `connect`) |
| `connect.datastore.rds.dbUser` | Output of `connect/database`: `connect_db_user` (default: `connect_api`) |
| `connect.datastore.rds.oidc.awsRegion` | AWS region |
| `connect.datastore.rds.oidc.iamRoleARN` | Output of `connect/iam-role`: `role_arn` |
| `connect.trustBundleStoreBackend.s3.bucket` | Output of `connect/bundle-bucket`: `bucket_name` |
| `connect.trustBundleStoreBackend.s3.oidc.awsRegion` | AWS region |
| `connect.trustBundleStoreBackend.s3.oidc.iamRoleARN` | Output of `connect/iam-role`: `role_arn` (same role) |
| `envoy.auth.issuer` | Identity provider issuer URL |
| `envoy.auth.jwksUri` | Identity provider JWKS URI |
| `envoy.auth.tlsSecretName` | `connect-tls` (matches the certificate name in `certificate/`) |

The Connect API envoy sidecar routes incoming TLS connections by SNI across three hostnames derived from `connect.urlBase` (the Route53 zone name): `connect.<urlBase>`, `connect-agent.<urlBase>`, and `xds.<urlBase>`. ExternalDNS creates DNS records for all three, and the cert-manager Certificate in `certificate/` covers the same names.

If there are Connect API values that need to persist across regenerations of `values.local.yaml` (for example `envoy.auth.audiences` or `connect.initialRBAC`), put them in `values.override.yaml` — `install.sh` merges it last so it takes precedence:

```sh
cp values.override.yaml.example values.override.yaml
```

If all base infra units (`base/eks-cluster/cluster`, `base/dns`, `base/database/rds-instance`) have been applied via this Terragrunt stack, you can generate `values.local.yaml` automatically instead:

```sh
./generate-local-values.sh <idp-issuer> <idp-jwks-uri> <ui-subdomain> <psat-audience>
# e.g: ./generate-local-values.sh https://auth.example.com https://auth.example.com/.well-known/jwks.json app connect
```

## Connect UI

```sh
cd connect/connect-ui
cp values.local.yaml.example values.local.yaml
# Set ui-subdomain, oauth-client-id, and oauth-issuer.
./install.sh
```

| Field in `values.local.yaml` | Where to get the value |
|------------------------------|------------------------|
| UI hostname / subdomain | The subdomain the Connect UI will be served on (e.g. `app`) |
| OAuth client ID | OAuth client ID from your identity provider |
| OAuth issuer | Issuer URL of your identity provider |

If the `base/dns` Terragrunt unit has been applied, you can generate `values.local.yaml` automatically instead:

```sh
./generate-local-values.sh <ui-subdomain> <oauth-client-id> <oauth-issuer>
```

## Accessing Connect

Once deployment steps are complete, run [`print-cofidectl-config.sh`](../../print-cofidectl-config.sh) to print the `cofidectl connect init` command with all values filled in then run the printed command to initialise your local cofidectl.

If you wish to remove all Connect reference deployment resource from your AWS account, see [Teardown](../../README.md)
