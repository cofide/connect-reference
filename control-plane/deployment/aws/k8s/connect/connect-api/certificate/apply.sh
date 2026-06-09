#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/certificate.local.yaml" ]]; then
  echo "Error: certificate.local.yaml not found."
  echo "Copy certificate.local.yaml.example to certificate.local.yaml and fill in your values."
  exit 1
fi

kubectl apply -k "${SCRIPT_DIR}"
