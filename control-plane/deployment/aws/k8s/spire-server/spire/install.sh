#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CHART_VERSION=$(yq '.chartVersion' "${SCRIPT_DIR}/versions.yaml")
if [[ -f "${SCRIPT_DIR}/versions.local.yaml" ]]; then
  CHART_VERSION=$(yq '.chartVersion' "${SCRIPT_DIR}/versions.local.yaml")
fi

if [[ ! -f "${SCRIPT_DIR}/values.local.yaml" ]]; then
  echo "Error: values.local.yaml not found."
  echo "Copy values.local.yaml.example to values.local.yaml and fill in your values."
  exit 1
fi

if ! kubectl get crd clusterspiffeids.spire.spiffe.io --ignore-not-found 2>/dev/null | grep -q clusterspiffeids; then
  echo "Error: spire-crds are not installed. Run spire-crds/install.sh first." >&2
  exit 1
fi

helm repo add cofide https://charts.cofide.dev
helm repo update cofide

helm upgrade --install spire cofide/spire \
  --version "${CHART_VERSION}" \
  --namespace spire-mgmt \
  -f "${SCRIPT_DIR}/values.yaml" \
  -f "${SCRIPT_DIR}/values.local.yaml"
