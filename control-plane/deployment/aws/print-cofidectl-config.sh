#!/bin/bash

# Prints the cofidectl connect init command with values derived from the
# Connect control plane setup.
#
# Requires the following to be in place:
#   infra/stack/base/dns/                    — provides the Connect URL
#   infra/stack/connect/bundle-distribution/ — provides the bundle host
#   spire Helm release in spire-mgmt         — provides the Connect trust domain
#   connect-ui Helm release in connect       — provides the OAuth client ID
#
# kubectl must be configured for the control-plane cluster when this script runs.
#
# Usage: ./print-cofidectl-config.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="${SCRIPT_DIR}/infra/stack"

echo "Reading zone name from base/dns..."
ZONE_NAME=$(terragrunt --working-dir "${STACK_DIR}/base/dns" output -raw zone_name)
CONNECT_URL="${ZONE_NAME}:443"

echo "Reading bundle distribution domain from connect/bundle-distribution..."
DIST_DOMAIN=$(terragrunt --working-dir "${STACK_DIR}/connect/bundle-distribution" output -raw distribution_domain_name)

echo "Reading Connect trust domain from deployed spire Helm release..."
CONNECT_TRUST_DOMAIN=$(helm get values spire --namespace spire-mgmt -o json | yq '.global.spire.trustDomain')

echo "Reading OAuth client ID from deployed connect-ui Helm release..."
OAUTH_CLIENT_ID=$(helm get values connect-ui --namespace connect -o json | yq '.ui.oauth.clientId')

echo ""
echo "Run the following command to initialise cofidectl:"
echo ""
echo "  cofidectl connect init \\"
echo "    --connect-url ${CONNECT_URL} \\"
echo "    --connect-trust-domain ${CONNECT_TRUST_DOMAIN} \\"
echo "    --connect-bundle-host ${DIST_DOMAIN} \\"
echo "    --oauth-client-id ${OAUTH_CLIENT_ID}"
