#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

helm repo add jetstack https://charts.jetstack.io
helm repo update jetstack

local_values_args=()
if [[ -f "${SCRIPT_DIR}/values.local.yaml" ]]; then
  local_values_args=(-f "${SCRIPT_DIR}/values.local.yaml")
fi

helm upgrade --install cert-manager jetstack/cert-manager \
  --version v1.20.2 \
  --namespace cert-manager \
  --create-namespace \
  -f "${SCRIPT_DIR}/values.yaml" \
  "${local_values_args[@]+"${local_values_args[@]}"}"
