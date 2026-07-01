#!/usr/bin/env bash

# Generates values.local.yaml from the Terragrunt infra stack outputs.
# Requires the following units to have been applied:
#   infra/stack/base/dns/
#   infra/stack/base/eks-cluster/cluster/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="${SCRIPT_DIR}/../../../infra/stack"

echo "Reading cluster name from base/eks-cluster/cluster..."
CLUSTER_NAME=$(terragrunt --working-dir "${STACK_DIR}/base/eks-cluster/cluster" output -raw cluster_name)
echo "  cluster_name: ${CLUSTER_NAME}"

echo "Reading region from base/eks-cluster/cluster..."
AWS_REGION=$(terragrunt --working-dir "${STACK_DIR}/base/eks-cluster/cluster" output -raw region)
echo "  region: ${AWS_REGION}"

echo "Reading hosted zone name from base/dns..."
ZONE_NAME=$(terragrunt --working-dir "${STACK_DIR}/base/dns" output -raw zone_name)
echo "  zone_name: ${ZONE_NAME}"

OUTPUT="${SCRIPT_DIR}/values.local.yaml"
cat > "${OUTPUT}" <<EOF
domainFilters:
  - ${ZONE_NAME}

txtOwnerId: ${CLUSTER_NAME}

env:
  - name: AWS_DEFAULT_REGION
    value: ${AWS_REGION}

# Optional: uncomment to use IRSA instead of EKS Pod Identity.
# Run: terragrunt --working-dir infra/stack/base/eks-cluster/controllers/external-dns output -raw role_arn
# serviceAccount:
#   annotations:
#     eks.amazonaws.com/role-arn: <role_arn>
EOF

echo "Written to ${OUTPUT}."
