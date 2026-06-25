#!/usr/bin/env bash

# Generates values.local.yaml from the Terragrunt infra stack outputs.
# Requires the following units to have been applied:
#   infra/stack/base/dns/
#   infra/stack/base/eks-cluster/cluster/
#   infra/stack/base/database/rds-instance/
#   infra/stack/connect/database/
#   infra/stack/connect/bundle-bucket/
#   infra/stack/connect/bundle-distribution/
#   infra/stack/connect/iam-role/
#
# Also requires the spire Helm release to be installed in the spire-mgmt namespace.
#
# Usage: ./generate-local-values.sh <idp-issuer> <idp-jwks-uri> <ui-subdomain> <psat-audience>
#   idp-issuer:     Issuer URL of the identity provider (e.g. https://auth.example.com)
#   idp-jwks-uri:   JWKS URI of the identity provider (e.g. https://auth.example.com/.well-known/jwks.json)
#   ui-subdomain:   Subdomain the Connect UI is served on (e.g. app); used to set the CORS allowed origin
#   psat-audience:  Expected audience in PSAT tokens sent by Cofide SPIRE servers when registering

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="${SCRIPT_DIR}/../../../infra/stack"

if [[ $# -lt 4 ]]; then
  echo "Usage: $(basename "$0") <idp-issuer> <idp-jwks-uri> <ui-subdomain> <psat-audience>"
  exit 1
fi
IDP_ISSUER="$1"
IDP_JWKS_URI="$2"
UI_SUBDOMAIN="$3"
PSAT_AUDIENCE="$4"

echo "Reading trust domain from deployed spire release..."
TRUST_DOMAIN=$(helm get values spire --namespace spire-mgmt --all -o json | jq -re '.global.spire.trustDomain')
echo "  trust_domain: ${TRUST_DOMAIN}"

echo "Reading region from base/eks-cluster/cluster..."
REGION=$(terragrunt --working-dir "${STACK_DIR}/base/eks-cluster/cluster" output -raw region)
echo "  region: ${REGION}"

echo "Reading hosted zone name from base/dns..."
ZONE_NAME=$(terragrunt --working-dir "${STACK_DIR}/base/dns" output -raw zone_name)
echo "  zone_name: ${ZONE_NAME}"

echo "Reading RDS host from base/database/rds-instance..."
DB_HOST=$(terragrunt --working-dir "${STACK_DIR}/base/database/rds-instance" output -raw db_host)
echo "  db_host: ${DB_HOST}"

echo "Reading RDS port from base/database/rds-instance..."
DB_PORT=$(terragrunt --working-dir "${STACK_DIR}/base/database/rds-instance" output -raw db_port)
echo "  db_port: ${DB_PORT}"

echo "Reading Connect database name from connect/database..."
CONNECT_DB_NAME=$(terragrunt --working-dir "${STACK_DIR}/connect/database" output -raw connect_db_name)
echo "  connect_db_name: ${CONNECT_DB_NAME}"

echo "Reading Connect database user from connect/database..."
CONNECT_DB_USER=$(terragrunt --working-dir "${STACK_DIR}/connect/database" output -raw connect_db_user)
echo "  connect_db_user: ${CONNECT_DB_USER}"

echo "Reading trust bundle bucket name from connect/bundle-bucket..."
S3_BUNDLE_BUCKET=$(terragrunt --working-dir "${STACK_DIR}/connect/bundle-bucket" output -raw bucket_name)
echo "  bucket_name: ${S3_BUNDLE_BUCKET}"

echo "Reading trust bundle distribution domain from connect/bundle-distribution..."
DISTRIBUTION_DOMAIN=$(terragrunt --working-dir "${STACK_DIR}/connect/bundle-distribution" output -raw distribution_domain_name)
echo "  distribution_domain_name: ${DISTRIBUTION_DOMAIN}"

echo "Reading IAM role ARN from connect/iam-role..."
ROLE_ARN=$(terragrunt --working-dir "${STACK_DIR}/connect/iam-role" output -raw role_arn)
echo "  role_arn: ${ROLE_ARN}"

# urlBase is the zone name; envoy routes connect.<zone>, connect-agent.<zone>, and xds.<zone>.
API_HOSTNAMES="connect.${ZONE_NAME},connect-agent.${ZONE_NAME},xds.${ZONE_NAME}"

OUTPUT="${SCRIPT_DIR}/values.local.yaml"
cat > "${OUTPUT}" <<EOF
service:
  annotations:
    # ExternalDNS creates records for all three SNI hostnames, all pointing to the same NLB.
    external-dns.alpha.kubernetes.io/hostname: ${API_HOSTNAMES}

connect:
  urlBase: ${ZONE_NAME}
  allowedOrigins:
    - "https://${UI_SUBDOMAIN}.${ZONE_NAME}"
  trustDomain: ${TRUST_DOMAIN}
  connectTrustBundleStoreURL: https://${DISTRIBUTION_DOMAIN}
  connectPSATAudience: ${PSAT_AUDIENCE}
  datastore:
    sqlConnectionString:
      enabled: false
    rds:
      enabled: true
      host: ${DB_HOST}
      port: ${DB_PORT}
      databaseName: ${CONNECT_DB_NAME}
      dbUser: ${CONNECT_DB_USER}
      oidc:
        awsRegion: ${REGION}
        iamRoleARN: ${ROLE_ARN}
        audience: sts.amazonaws.com
  trustBundleStoreBackend:
    s3:
      enabled: true
      bucket: ${S3_BUNDLE_BUCKET}
      oidc:
        enabled: true
        awsRegion: ${REGION}
        iamRoleARN: ${ROLE_ARN}
        audience: sts.amazonaws.com

envoy:
  auth:
    issuer: ${IDP_ISSUER}
    jwksUri: ${IDP_JWKS_URI}
    tlsSecretName: connect-tls

# Optional: uncomment to use IRSA instead of EKS Pod Identity.
# serviceAccount:
#   annotations:
#     eks.amazonaws.com/role-arn: ${ROLE_ARN}
EOF

echo "Written to ${OUTPUT}."
