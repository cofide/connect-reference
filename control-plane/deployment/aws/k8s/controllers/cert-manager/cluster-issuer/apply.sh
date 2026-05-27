#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/cluster-issuer.local.yaml" ]]; then
  echo "Error: cluster-issuer.local.yaml not found."
  echo "Copy cluster-issuer.local.yaml.example to cluster-issuer.local.yaml and fill in your values."
  exit 1
fi

kubectl apply -k "${SCRIPT_DIR}"
