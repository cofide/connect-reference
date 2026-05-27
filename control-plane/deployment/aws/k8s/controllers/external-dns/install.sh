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

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update external-dns

helm upgrade --install external-dns external-dns/external-dns \
  --version "${CHART_VERSION}" \
  --namespace external-dns \
  --create-namespace \
  -f "${SCRIPT_DIR}/values.yaml" \
  -f "${SCRIPT_DIR}/values.local.yaml"
