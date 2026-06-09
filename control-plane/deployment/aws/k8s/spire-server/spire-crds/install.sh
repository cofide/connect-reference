#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CHART_VERSION=$(yq '.chartVersion' "${SCRIPT_DIR}/versions.yaml")
if [[ -f "${SCRIPT_DIR}/versions.local.yaml" ]]; then
  CHART_VERSION=$(yq '.chartVersion' "${SCRIPT_DIR}/versions.local.yaml")
fi

helm repo add cofide https://charts.cofide.dev
helm repo update cofide

helm upgrade --install spire-crds cofide/spire-crds \
  --version "${CHART_VERSION}" \
  --namespace spire-mgmt \
  --create-namespace
