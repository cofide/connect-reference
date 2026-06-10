#!/bin/bash

# Generates values.local.yaml from the Terragrunt infra stack outputs and
# command-line arguments.
#
# Requires the following units to have been applied:
#   infra/stack/eks-cluster/cluster/
#   infra/stack/spire-server/iam-role/
#   infra/stack/spire-server/agent-iam-role/
#   infra/stack/connect/trust-zone/
#   control-plane/deployment/aws/infra/stack/base/dns/
#   control-plane/deployment/aws/infra/stack/connect/bundle-distribution/
#
# COFIDE_API_TOKEN must be set for the connect/ Terragrunt units.
# kubectl must be configured for the control-plane cluster to read the connect Helm release.
#
# Usage: ./generate-local-values.sh <ca-country> <ca-organization> <ca-common-name>
#   ca-country:      Country code for the upstream CA certificate subject (e.g. GB)
#   ca-organization: Organization name for the upstream CA certificate subject
#   ca-common-name:  Common name for the upstream CA certificate subject
#
# The PSAT audience is read from the connect-api Helm release in the connect namespace.
# kubectl must be configured for the control-plane cluster when this script runs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="${SCRIPT_DIR}/../../../infra/stack"
REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel)"
CP_STACK_DIR="${REPO_ROOT}/control-plane/deployment/aws/infra/stack"

if [[ $# -lt 3 ]]; then
  echo "Usage: $(basename "$0") <ca-country> <ca-organization> <ca-common-name>"
  exit 1
fi
CA_COUNTRY="$1"
CA_ORGANIZATION="$2"
CA_COMMON_NAME="$3"

echo "Reading region from eks-cluster/cluster..."
REGION=$(terragrunt --working-dir "${STACK_DIR}/eks-cluster/cluster" output -raw region)
echo "  region: ${REGION}"

echo "Reading IAM role ARN from spire-server/iam-role..."
ROLE_ARN=$(terragrunt --working-dir "${STACK_DIR}/spire-server/iam-role" output -raw role_arn)
echo "  role_arn: ${ROLE_ARN}"

echo "Reading agent IAM role ARN from spire-server/agent-iam-role..."
AGENT_ROLE_ARN=$(terragrunt --working-dir "${STACK_DIR}/spire-server/agent-iam-role" output -raw role_arn)
echo "  agent_role_arn: ${AGENT_ROLE_ARN}"

echo "Reading zone name from control-plane base/dns..."
CP_ZONE_NAME=$(terragrunt --working-dir "${CP_STACK_DIR}/base/dns" output -raw zone_name)
CONNECT_URL="${CP_ZONE_NAME}:443"
echo "  connect_url: ${CONNECT_URL}"

echo "Reading bundle distribution domain from control-plane connect/bundle-distribution..."
CP_DIST_DOMAIN=$(terragrunt --working-dir "${CP_STACK_DIR}/connect/bundle-distribution" output -raw distribution_domain_name)
echo "  distribution_domain: ${CP_DIST_DOMAIN}"

echo "Reading Connect trust domain from deployed spire Helm release (control-plane cluster)..."
CONNECT_TRUST_DOMAIN=$(helm get values spire --namespace spire-mgmt -o json | yq '.global.spire.trustDomain')
echo "  connect_trust_domain: ${CONNECT_TRUST_DOMAIN}"

CONNECT_BUNDLE_ENDPOINT_URL="https://${CP_DIST_DOMAIN}/${CONNECT_TRUST_DOMAIN}/bundle"
echo "  bundle_endpoint_url: ${CONNECT_BUNDLE_ENDPOINT_URL}"

echo "Reading PSAT audience from deployed connect-api Helm release (control-plane cluster)..."
PSAT_AUDIENCE=$(helm get values connect --namespace connect -o json | yq '.connect.connectPSATAudience')
echo "  psat_audience: ${PSAT_AUDIENCE}"

echo "Reading trust domain, trust zone ID, cluster ID, and cluster name from connect/trust-zone..."
TRUST_DOMAIN=$(terragrunt --working-dir "${STACK_DIR}/connect/trust-zone" output -raw trust_domain)
echo "  trust_domain: ${TRUST_DOMAIN}"
TRUST_ZONE_ID=$(terragrunt --working-dir "${STACK_DIR}/connect/trust-zone" output -raw trust_zone_id)
echo "  trust_zone_id: ${TRUST_ZONE_ID}"
CLUSTER_ID=$(terragrunt --working-dir "${STACK_DIR}/connect/trust-zone" output -raw cluster_id)
echo "  cluster_id: ${CLUSTER_ID}"
CLUSTER_NAME=$(terragrunt --working-dir "${STACK_DIR}/connect/trust-zone" output -raw cluster_name)
echo "  cluster_name: ${CLUSTER_NAME}"

OUTPUT="${SCRIPT_DIR}/values.local.yaml"
cat > "${OUTPUT}" <<EOF
global:
  spire:
    clusterName: ${CLUSTER_NAME}
    trustDomain: ${TRUST_DOMAIN}
    # If the OIDC discovery provider is cluster-internal (ClusterIP), use its
    # in-cluster service address. Update this if you expose the provider externally.
    jwtIssuer: https://spire-spiffe-oidc-discovery-provider.spire-system.svc.cluster.local
    caSubject:
      country: ${CA_COUNTRY}
      organization: ${CA_ORGANIZATION}
      commonName: ${CA_COMMON_NAME}

spire-server:
  dataStore:
    connect:
      url: ${CONNECT_URL}
      trustDomain: ${CONNECT_TRUST_DOMAIN}
      bundleEndpointURL: ${CONNECT_BUNDLE_ENDPOINT_URL}
      clusterID: ${CLUSTER_ID}
      trustZoneID: ${TRUST_ZONE_ID}
      auth:
        method: psat
        psatExpirationSeconds: 900
        psatAudience: ${PSAT_AUDIENCE}
  keyManager:
    awsKMS:
      region: ${REGION}
  upstreamAuthority:
    certManager:
      ca:
        issuerRef:
          name: selfsigned
          kind: ClusterIssuer

spire-agent:
  unsupportedBuiltInPlugins:
    # Note: the key must be lowercase 'svidstore' (not 'svidStore') to match the chart's
    # template check, which maps it to the 'SVIDStore' SPIRE plugin section.
    svidstore:
      aws_secretsmanager:
        plugin_data:
          region: ${REGION}

# Optional: uncomment to use IRSA instead of EKS Pod Identity.
# spire-server:
#   serviceAccount:
#     annotations:
#       eks.amazonaws.com/role-arn: ${ROLE_ARN}
# spire-agent:
#   serviceAccount:
#     annotations:
#       eks.amazonaws.com/role-arn: ${AGENT_ROLE_ARN}
EOF

echo "Written to ${OUTPUT}."
