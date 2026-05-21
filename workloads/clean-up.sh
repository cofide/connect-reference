#!/bin/bash

set -uxo pipefail

# This script cleans up Kubernetes resources in one or more clusters.
# This includes the ping-pong demo, Cofide agent and SPIRE components.
# It does not delete the associated resources in Connect.

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <context 1>[, <context 2>...]"
  exit 1
fi

CONTEXTS=$@
for CONTEXT in $CONTEXTS; do
  echo "Cleaning up context $CONTEXT"
  echo "Cleaning up ping-pong demo"
  kubectl delete deployment ping-pong-server -n production --context $CONTEXT --wait
  kubectl delete deployment ping-pong-client -n production --context $CONTEXT --wait
  kubectl delete pods -n production --all --context $CONTEXT --wait
  kubectl delete ns production --context $CONTEXT --wait

  echo "Cleaning up Cofide agent"
  helm uninstall cofide-agent --kube-context $CONTEXT -n cofide --wait

  echo "Waiting for pods using the SPIFFE CSI driver to terminate"
  while [[ $(kubectl get pods -o jsonpath='{.items[?(@.spec.volumes[*].csi.driver=="csi.spiffe.io")].metadata.name}' -A --context $CONTEXT) != "" ]]; do
    sleep 5
  done

  echo "Cleaning up SPIRE components"
  helm uninstall spire -n spire-mgmt --kube-context $CONTEXT --wait
  helm uninstall spire-crds -n spire-mgmt --kube-context $CONTEXT --wait
done
echo "Clean up complete"
