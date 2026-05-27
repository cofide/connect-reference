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

helm repo add cofide https://charts.cofide.dev
helm repo update cofide

helm upgrade --install connect-ui cofide/cofide-connect-ui \
  --version "${CHART_VERSION}" \
  --namespace connect \
  -f "${SCRIPT_DIR}/values.yaml" \
  -f "${SCRIPT_DIR}/values.local.yaml"
