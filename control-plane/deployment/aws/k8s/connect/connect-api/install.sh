#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/values.local.yaml" ]]; then
  echo "Error: values.local.yaml not found."
  echo "Copy values.local.yaml.example to values.local.yaml and fill in your values."
  exit 1
fi

helm repo add cofide https://charts.cofide.dev
helm repo update cofide

OVERRIDE_VALUES_ARGS=()
if [[ -f "${SCRIPT_DIR}/values.override.yaml" ]]; then
  OVERRIDE_VALUES_ARGS=(-f "${SCRIPT_DIR}/values.override.yaml")
fi

helm upgrade --install connect cofide/cofide-connect \
  --version 0.20.0 \
  --namespace connect \
  -f "${SCRIPT_DIR}/values.yaml" \
  -f "${SCRIPT_DIR}/values.local.yaml" \
  "${OVERRIDE_VALUES_ARGS[@]}"
