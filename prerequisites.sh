#!/bin/bash

# This script performs prerequisites necessary for using Connect and cofidectl.

set -euxo pipefail

for cmd in aws cofidectl curl docker helm kubectl uuidgen; do
  if ! type $cmd; then
    echo "Unable to find $cmd"
    exit 1
  fi
done

# Minimum kind version so default Kubernetes cluster version includes sidecar containers
# https://kubernetes.io/blog/2025/04/23/kubernetes-v1-33-release/#stable-sidecar-containers
min_version="0.30.0"
current_version=$(kind version | awk '{print $2}' | sed 's/^v//')
if ! printf '%s\n%s\n' "$min_version" "$current_version" | sort -V -C &>/dev/null; then
  echo "Kind version v${min_version} or higher is required, but found v${current_version}."
  exit 1
fi

./login.sh
