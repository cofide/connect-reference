#!/bin/bash

# Generates certificate.local.yaml from the Terragrunt infra stack outputs.
# Requires the following unit to have been applied:
#   infra/stack/base/dns/
#
# Usage: ./generate-certificate-local.sh <ui-subdomain>
#   ui-subdomain: Subdomain for the Connect UI (e.g. app)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="${SCRIPT_DIR}/../../../../infra/stack"

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <ui-subdomain>"
  exit 1
fi
UI_SUBDOMAIN="$1"

echo "Reading hosted zone name from base/dns..."
ZONE_NAME=$(terragrunt --working-dir "${STACK_DIR}/base/dns" output -raw zone_name)
echo "  zone_name: ${ZONE_NAME}"

UI_HOSTNAME="${UI_SUBDOMAIN}.${ZONE_NAME}"

OUTPUT="${SCRIPT_DIR}/certificate.local.yaml"
cat > "${OUTPUT}" <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: connect-ui-tls
  namespace: connect
spec:
  dnsNames:
    - ${UI_HOSTNAME}
EOF

echo "Written to ${OUTPUT}."
