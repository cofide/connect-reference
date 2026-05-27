#!/bin/bash

# Generates values.local.yaml from the Terragrunt infra stack outputs.
# Requires the following units to have been applied:
#   infra/stack/base/vpc/
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

echo "Reading VPC ID from base/vpc..."
VPC_ID=$(terragrunt --working-dir "${STACK_DIR}/base/vpc" output -raw vpc_id)
echo "  vpc_id: ${VPC_ID}"

OUTPUT="${SCRIPT_DIR}/values.local.yaml"
cat > "${OUTPUT}" <<EOF
clusterName: ${CLUSTER_NAME}
region: ${AWS_REGION}
vpcId: ${VPC_ID}

# Optional: uncomment to use IRSA instead of EKS Pod Identity.
# Run: terragrunt --working-dir infra/stack/base/eks-cluster/controllers/aws-load-balancer-controller output -raw role_arn
# serviceAccount:
#   annotations:
#     eks.amazonaws.com/role-arn: <role_arn>
EOF

echo "Written to ${OUTPUT}."
