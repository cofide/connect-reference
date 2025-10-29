#!/usr/bin/env bash

# This script logs into Connect and AWS ECR, refreshing any existing tokens.

set -euxo pipefail

source config.env

rm -f cofide.yaml
cofidectl connect init \
  --connect-url $CONNECT_URL \
  --connect-trust-domain $CONNECT_TRUST_DOMAIN \
  --connect-bundle-host $CONNECT_BUNDLE_HOST \
  --authorization-domain $AUTHORIZATION_DOMAIN \
  --authorization-client-id $AUTHORIZATION_CLIENT_ID \
  --connect-datasource

if ! cofidectl connect login --check; then
  cofidectl connect login
fi

if ! aws sts get-caller-identity; then
  aws sso login
fi

if [[ ${LOCAL} == "true" ]]; then
  aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 010438484483.dkr.ecr.eu-west-1.amazonaws.com
  aws ecr get-login-password --region eu-west-1 | helm registry login --username AWS --password-stdin 010438484483.dkr.ecr.eu-west-1.amazonaws.com
fi
