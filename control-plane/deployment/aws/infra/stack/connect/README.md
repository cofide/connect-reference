# Connect Infrastructure

Terraform units that provision the AWS resources needed by the Connect API. These must be applied after the SPIRE server is running and its OIDC discovery endpoint is publicly reachable — `connect/iam-role` registers the endpoint as an AWS IAM identity provider, which requires a live TLS connection at apply time.

## Units

### `bundle-bucket/`

Creates a KMS-encrypted S3 bucket that the Connect API writes trust bundles to. Has no dependencies and can be applied independently.

```sh
cd connect/bundle-bucket 
cp common.local.hcl.example common.local.hcl
# Set bucket_name in common.local.hcl
terragrunt apply
```

### `bundle-distribution/`

Creates a CloudFront distribution in front of the bundle bucket to serve trust bundles over a stable public HTTPS URL. Requires `bundle-bucket/` and `base/dns/`.

```sh
cd connect/bundle-distribution
cp common.local.hcl.example common.local.hcl
# Set bundle_domain to the subdomain for trust bundle delivery (e.g. bundles.example.com).
terragrunt apply
```

### `database/`

Creates the `connect` PostgreSQL database and role, connecting to the RDS instance as `iam_admin` using IAM token authentication.

The SSM database tunnel must be open (see [`../base/database/rds-instance/README.md`](../base/database/rds-instance/README.md)) and the IAM identity running Terragrunt must have `rds-db:connect` permission for `iam_admin`.

```sh
cd connect/database && terragrunt apply
```

`bundle-distribution/` and `database/` have no dependency on each other and can be applied in parallel.

### `iam-role/`

Creates the IAM role for the Connect API with:
- SPIFFE JWT SVID authentication via the SPIRE OIDC provider
- RDS IAM authentication permission for the `connect` database user
- S3 permissions (`PutObject`, `PutObjectTagging`, `DeleteObject`, `ListBucket`) on the bundle bucket
- KMS permission (`GenerateDataKey`) for the bundle bucket encryption key

`spire_oidc_domain` and `spiffe_id` must be set in `common.local.hcl` before applying:

```sh
cd connect/iam-role
cp common.local.hcl.example common.local.hcl
# Set spire_oidc_domain and spiffe_id (see common.local.hcl.example for details).
terragrunt apply
```

`spire_oidc_domain` is the fully-qualified domain of the SPIRE OIDC discovery endpoint (e.g. `oidc-discovery.example.com`). `spiffe_id` is the SPIFFE ID of the Connect API workload (e.g. `spiffe://<trust-domain>/ns/connect/sa/cofide-connect-api`).

## Alternative trust bundle exposure

`connect.connectTrustBundleStoreURL` in the Connect API Helm values points to the trust bundle URL. It must be a stable HTTPS endpoint reachable by the Cofide SPIRE servers managing Connect trust zones.

The `bundle-distribution/` unit provisions CloudFront for this, but any HTTPS endpoint in front of the same S3 bucket works. To use an alternative, skip `bundle-distribution/` and set `connect.connectTrustBundleStoreURL` to your endpoint. The `bundle-bucket/` unit and the IAM role policy remain unchanged — Connect only needs `s3:PutObject`, `s3:PutObjectTagging`, `s3:DeleteObject`, and `s3:ListBucket` on the bucket regardless of what fronts it.
