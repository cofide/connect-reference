#!/usr/bin/env bash

# Generates values.local.yaml from the Terragrunt infra stack outputs.
# Requires the following units to have been applied:
#   infra/stack/base/dns/
#
# Usage: ./generate-local-values.sh <ui-subdomain> <oauth-client-id> <oauth-issuer>
#   ui-subdomain:    Subdomain for the Connect UI (e.g. app)
#   oauth-client-id: OAuth client ID for the identity provider
#   oauth-issuer:    Issuer URL of the identity provider (e.g. https://auth.example.com)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="${SCRIPT_DIR}/../../../infra/stack"

if [[ $# -lt 3 ]]; then
  echo "Usage: $(basename "$0") <ui-subdomain> <oauth-client-id> <oauth-issuer>"
  exit 1
fi
UI_SUBDOMAIN="$1"
OAUTH_CLIENT_ID="$2"
OAUTH_ISSUER="$3"

echo "Reading hosted zone name from base/dns..."
ZONE_NAME=$(terragrunt --working-dir "${STACK_DIR}/base/dns" output -raw zone_name)
echo "  zone_name: ${ZONE_NAME}"

UI_HOSTNAME="${UI_SUBDOMAIN}.${ZONE_NAME}"
API_URL="https://connect.${ZONE_NAME}"

OUTPUT="${SCRIPT_DIR}/values.local.yaml"
cat > "${OUTPUT}" <<EOF
service:
  annotations:
    external-dns.alpha.kubernetes.io/hostname: ${UI_HOSTNAME}

ui:
  hostname: ${UI_HOSTNAME}
  connectUrl: ${API_URL}
  oauth:
    clientId: ${OAUTH_CLIENT_ID}
    issuer: ${OAUTH_ISSUER}

envoy:
  tlsSecretName: connect-ui-tls
EOF

echo "Written to ${OUTPUT}."
