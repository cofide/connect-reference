#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CHART_VERSION=$(yq '.chartVersion' "${SCRIPT_DIR}/versions.yaml")
if [[ -f "${SCRIPT_DIR}/versions.local.yaml" ]]; then
  CHART_VERSION=$(yq '.chartVersion' "${SCRIPT_DIR}/versions.local.yaml")
fi

helm repo add jetstack https://charts.jetstack.io
helm repo update jetstack

local_values_args=()
if [[ -f "${SCRIPT_DIR}/values.local.yaml" ]]; then
  local_values_args=(-f "${SCRIPT_DIR}/values.local.yaml")
fi

helm upgrade --install cert-manager jetstack/cert-manager \
  --version "${CHART_VERSION}" \
  --namespace cert-manager \
  --create-namespace \
  -f "${SCRIPT_DIR}/values.yaml" \
  "${local_values_args[@]+"${local_values_args[@]}"}"
