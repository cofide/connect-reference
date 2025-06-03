#!/bin/bash

set -euxo pipefail

# This script creates a kind cluster and defines a trust zone, cluster,
# attestation policy and binding in the staging Connect using cofidectl and terraform-provider-cofide.
# It then runs a ping-pong test.

# Prerequisites: ./prerequisites.sh

source config.env

## Deploy workload cluster

# Generate unique ID for cluster, trust zone & trust domain disambiguation
UNIQUE_ID=$(uuidgen | head -c 8 | tr A-Z a-z)

WORKLOAD_K8S_CLUSTER_NAME="${WORKLOAD_K8S_CLUSTER_NAME:-workload-${UNIQUE_ID}}"
WORKLOAD_K8S_CLUSTER_CONTEXT="${WORKLOAD_K8S_CLUSTER_CONTEXT:-kind-workload-${UNIQUE_ID}}"
# Trust zones must be unique within a single Cofide Connect service.
WORKLOAD_TRUST_ZONE=${WORKLOAD_TRUST_ZONE:-${UNIQUE_ID}}
# Trust domains must currently be globally unique due to a shared S3 bucket for hosting bundles.
WORKLOAD_TRUST_DOMAIN=${WORKLOAD_TRUST_DOMAIN:-${UNIQUE_ID}.test}

kind delete cluster --name $WORKLOAD_K8S_CLUSTER_NAME

# Patch in host Docker config in order to enable pulling images
# to the Kind cluster. This envsubst approach is required as Kind does
# not support ~ or $HOME directly in the extraMounts attribute of the config
# https://github.com/kubernetes-sigs/kind/issues/3642
export PATH_TO_HOST_DOCKER_CREDENTIALS=$HOME/.docker/config.json
envsubst < templates/kind_workload_config_template.yaml > generated/kind_workload_config.yaml
kind create cluster --name $WORKLOAD_K8S_CLUSTER_NAME --config generated/kind_workload_config.yaml

## Deploy workload identity infrastructure using cofidectl and terraform-provider-cofide

rm -f cofide.yaml
cofidectl connect init \
  --connect-url $CONNECT_URL \
  --connect-trust-domain $CONNECT_TRUST_DOMAIN \
  --connect-bundle-host $CONNECT_BUNDLE_HOST \
  --authorization-domain $AUTHORIZATION_DOMAIN \
  --authorization-client-id $AUTHORIZATION_CLIENT_ID \
  --connect-datasource

set +x
ACCESS_TOKEN=$(grep 'cofide_access_token' ~/.cofide/credentials | cut -d'=' -f2)
if [ -z "${ACCESS_TOKEN}" ]; then
  echo "ERROR: Failed to get access token" >&2
  exit 1
fi
export COFIDE_API_TOKEN="${ACCESS_TOKEN}"
set -x

export COFIDE_CONNECT_URL="${CONNECT_URL}"

# Set this to true if running against a local instance of Connect.
export COFIDE_INSECURE_SKIP_VERIFY=false

export TF_VAR_trust_zone_name="${WORKLOAD_TRUST_ZONE}"
export TF_VAR_trust_domain="${WORKLOAD_TRUST_DOMAIN}"
export TF_VAR_cluster_name="${WORKLOAD_K8S_CLUSTER_NAME}"
export TF_VAR_cluster_kubernetes_context="${WORKLOAD_K8S_CLUSTER_CONTEXT}"
export TF_VAR_attestation_policy_name="${NAMESPACE}-ns-${WORKLOAD_TRUST_ZONE}"
export TF_VAR_attestation_policy_namespace="${NAMESPACE}"

terraform -chdir=./terraform/single-trust-zone init -input=false -backend=false

## Ensures that any resources from previous runs have been deleted first.
terraform -chdir=./terraform/single-trust-zone destroy -input=false -auto-approve
terraform -chdir=./terraform/single-trust-zone apply -input=false -auto-approve

cofidectl up --trust-zone $WORKLOAD_TRUST_ZONE

## Validate the deployment using ping-pong demo

kubectl --context $WORKLOAD_K8S_CLUSTER_CONTEXT create namespace $NAMESPACE

SERVER_CTX=$WORKLOAD_K8S_CLUSTER_CONTEXT
CLIENT_CTX=$WORKLOAD_K8S_CLUSTER_CONTEXT

export IMAGE_TAG=v0.1.10 # Version of cofide-demos to use
COFIDE_DEMOS_BRANCH="https://raw.githubusercontent.com/cofide/cofide-demos/refs/tags/$IMAGE_TAG"

SERVER_MANIFEST="$COFIDE_DEMOS_BRANCH/workloads/ping-pong/ping-pong-server/deploy.yaml"
export PING_PONG_SERVER_SERVICE_PORT=8443
if ! curl --fail $SERVER_MANIFEST | envsubst | kubectl apply -n "$NAMESPACE" --context "$SERVER_CTX" -f -; then
  echo "Error: Server deployment failed" >&2
  exit 1
fi
echo "Server deployment complete"

export PING_PONG_SERVER_SERVICE_HOST=ping-pong-server
CLIENT_MANIFEST="$COFIDE_DEMOS_BRANCH/workloads/ping-pong/ping-pong-client/deploy.yaml"
if ! curl --fail $CLIENT_MANIFEST | envsubst | kubectl apply --context "$CLIENT_CTX" -n "$NAMESPACE" -f -; then
  echo "Error: client deployment failed" >&2
  exit 1
fi
echo "Client deployment complete"

kubectl --context $CLIENT_CTX wait -n $NAMESPACE --for=condition=Available --timeout 60s deployments/ping-pong-client
kubectl --context $CLIENT_CTX logs -n $NAMESPACE deployments/ping-pong-client -f
