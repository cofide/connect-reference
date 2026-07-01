#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# To find available versions: helm search repo cofide/spire --devel
helm upgrade --install spire cofide/spire \
  --version 0.28.3-cofide.3 \
  --namespace spire-mgmt \
  -f "${SCRIPT_DIR}/values.yaml" \
  -f "${SCRIPT_DIR}/values.local.yaml"
