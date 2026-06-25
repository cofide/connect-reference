#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/values.local.yaml" ]]; then
  echo "Error: values.local.yaml not found."
  echo "Copy values.local.yaml.example to values.local.yaml and fill in your values."
  exit 1
fi

helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --version 3.3.0 \
  --namespace kube-system \
  -f "${SCRIPT_DIR}/values.yaml" \
  -f "${SCRIPT_DIR}/values.local.yaml"
