#!/usr/bin/env bash

set -euo pipefail

helm repo add cofide https://charts.cofide.dev
helm repo update cofide

# To find available versions: helm search repo cofide/spire-crds --devel
helm upgrade --install spire-crds cofide/spire-crds \
  --version 0.5.0-cofide.1 \
  --namespace spire-mgmt \
  --create-namespace
