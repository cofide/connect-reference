#!/usr/bin/env bash

# Generates values.local.yaml from the Terragrunt infra stack outputs.
# Requires the following units to have been applied:
#   infra/stack/base/dns/
#   infra/stack/base/eks-cluster/cluster/
#   infra/stack/base/database/rds-instance/
#   infra/stack/spire-server/database/
#   infra/stack/spire-server/iam-role/
#
# Usage: ./generate-local-values.sh <trust-domain> <oidc-subdomain> <ca-country> <ca-organization> <ca-common-name>
#   trust-domain:    SPIRE trust domain (e.g. connect.example.cofide.dev)
#   oidc-subdomain:  Subdomain for the OIDC discovery provider (e.g. oidc-discovery)
#   ca-country:      Country code for the upstream CA certificate subject (e.g. GB)
#   ca-organization: Organization name for the upstream CA certificate subject (e.g. "Example Ltd")
#   ca-common-name:  Common name for the upstream CA certificate subject (e.g. "Example Ltd SPIRE Root CA")

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="${SCRIPT_DIR}/../../../infra/stack"

if [[ $# -lt 5 ]]; then
  echo "Usage: $(basename "$0") <trust-domain> <oidc-subdomain> <ca-country> <ca-organization> <ca-common-name>"
  exit 1
fi
TRUST_DOMAIN="$1"
OIDC_SUBDOMAIN="$2"
CA_COUNTRY="$3"
CA_ORGANIZATION="$4"
CA_COMMON_NAME="$5"

echo "Reading cluster name from base/eks-cluster/cluster..."
CLUSTER_NAME=$(terragrunt --working-dir "${STACK_DIR}/base/eks-cluster/cluster" output -raw cluster_name)
echo "  cluster_name: ${CLUSTER_NAME}"

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

echo "Reading SPIRE database name from spire-server/database..."
SPIRE_DB_NAME=$(terragrunt --working-dir "${STACK_DIR}/spire-server/database" output -raw spire_db_name)
echo "  spire_db_name: ${SPIRE_DB_NAME}"

echo "Reading SPIRE database user from spire-server/database..."
SPIRE_DB_USER=$(terragrunt --working-dir "${STACK_DIR}/spire-server/database" output -raw spire_db_user)
echo "  spire_db_user: ${SPIRE_DB_USER}"

echo "Reading IAM role ARN from spire-server/iam-role..."
ROLE_ARN=$(terragrunt --working-dir "${STACK_DIR}/spire-server/iam-role" output -raw role_arn)
echo "  role_arn: ${ROLE_ARN}"

OIDC_HOSTNAME="${OIDC_SUBDOMAIN}.${ZONE_NAME}"

OUTPUT="${SCRIPT_DIR}/values.local.yaml"
cat > "${OUTPUT}" <<EOF
global:
  spire:
    clusterName: ${CLUSTER_NAME}
    trustDomain: ${TRUST_DOMAIN}
    jwtIssuer: https://${OIDC_HOSTNAME}
    caSubject:
      country: ${CA_COUNTRY}
      organization: ${CA_ORGANIZATION}
      commonName: ${CA_COMMON_NAME}

spiffe-oidc-discovery-provider:
  service:
    annotations:
      external-dns.alpha.kubernetes.io/hostname: ${OIDC_HOSTNAME}
  tls:
    certManager:
      certificate:
        issuerRef:
          name: letsencrypt
        dnsNames:
          - ${OIDC_HOSTNAME}

spire-server:
  dataStore:
    sql:
      region: ${REGION}
      host: ${DB_HOST}
      port: ${DB_PORT}
      databaseName: ${SPIRE_DB_NAME}
      username: ${SPIRE_DB_USER}
  keyManager:
    awsKMS:
      region: ${REGION}

# Optional: uncomment to use IRSA instead of EKS Pod Identity.
# spire-server:
#   serviceAccount:
#     annotations:
#       eks.amazonaws.com/role-arn: ${ROLE_ARN}
EOF

echo "Written to ${OUTPUT}."
