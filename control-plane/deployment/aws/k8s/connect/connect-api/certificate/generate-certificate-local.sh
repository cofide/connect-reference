#!/usr/bin/env bash

# Generates certificate.local.yaml from the Terragrunt infra stack outputs.
# Requires the following unit to have been applied:
#   infra/stack/base/dns/
#
# Usage: ./generate-certificate-local.sh
# The certificate covers connect.<zone>, connect-agent.<zone>, and xds.<zone>,
# matching the SNI hostnames used by the Connect API envoy sidecar.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="${SCRIPT_DIR}/../../../../infra/stack"

echo "Reading hosted zone name from base/dns..."
ZONE_NAME=$(terragrunt --working-dir "${STACK_DIR}/base/dns" output -raw zone_name)
echo "  zone_name: ${ZONE_NAME}"

OUTPUT="${SCRIPT_DIR}/certificate.local.yaml"
cat > "${OUTPUT}" <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: connect-tls
  namespace: connect
spec:
  dnsNames:
    - connect.${ZONE_NAME}
EOF

echo "Written to ${OUTPUT}."
