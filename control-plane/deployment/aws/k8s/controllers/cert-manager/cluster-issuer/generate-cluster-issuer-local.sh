#!/bin/bash

# Generates cluster-issuer.local.yaml from the Terragrunt infra stack outputs.
# Requires the following unit to have been applied:
#   infra/stack/base/dns/
#
# Usage: ./generate-cluster-issuer-local.sh <acme-email>
#   acme-email: email address for Let's Encrypt account registration.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="${SCRIPT_DIR}/../../../../infra/stack"

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <acme-email>"
  exit 1
fi
ACME_EMAIL="$1"

echo "Reading region from base/dns..."
AWS_REGION=$(terragrunt --working-dir "${STACK_DIR}/base/dns" output -raw region)
echo "  region: ${AWS_REGION}"

echo "Reading hosted zone ID from base/dns..."
HOSTED_ZONE_ID=$(terragrunt --working-dir "${STACK_DIR}/base/dns" output -raw zone_id)
echo "  zone_id: ${HOSTED_ZONE_ID}"

OUTPUT="${SCRIPT_DIR}/cluster-issuer.local.yaml"
cat > "${OUTPUT}" <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    email: ${ACME_EMAIL}
    solvers:
      - dns01:
          route53:
            region: ${AWS_REGION}
            hostedZoneID: ${HOSTED_ZONE_ID}
EOF

echo "Written to ${OUTPUT}."
