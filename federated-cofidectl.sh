#!/bin/bash

set -euxo pipefail

# This script creates a pair of kind clusters and defines trust zones,
# clusters, an attestation policy, bindings and federations in the staging
# Connect using cofidectl. It then runs a ping-pong test between the trust
# zones.

# Prerequisites: ./prerequisites.sh

source config.env

## Deploy workload cluster

# Generate unique ID for cluster, trust zone & trust domain disambiguation
UNIQUE_ID=$(uuidgen | head -c 8 | tr A-Z a-z)

WORKLOAD_K8S_CLUSTER_NAME_1="workload-${UNIQUE_ID}-1"
WORKLOAD_K8S_CLUSTER_CONTEXT_1="kind-workload-${UNIQUE_ID}-1"
# Trust zones must be unique within a single Cofide Connect service.
WORKLOAD_TRUST_ZONE_1="${UNIQUE_ID}-1"
# Trust domains must currently be globally unique due to a shared S3 bucket for hosting bundles.
WORKLOAD_TRUST_DOMAIN_1="${UNIQUE_ID}-1.test"

WORKLOAD_K8S_CLUSTER_NAME_2="workload-${UNIQUE_ID}-2"
WORKLOAD_K8S_CLUSTER_CONTEXT_2="kind-workload-${UNIQUE_ID}-2"
# Trust zones must be unique within a single Cofide Connect service.
WORKLOAD_TRUST_ZONE_2="${UNIQUE_ID}-2"
# Trust domains must currently be globally unique due to a shared S3 bucket for hosting bundles.
WORKLOAD_TRUST_DOMAIN_2="${UNIQUE_ID}-2.test"

kind delete cluster --name $WORKLOAD_K8S_CLUSTER_NAME_1
kind delete cluster --name $WORKLOAD_K8S_CLUSTER_NAME_2

# Patch in host Docker config in order to enable pulling images
# to the Kind cluster. This envsubst approach is required as Kind does
# not support ~ or $HOME directly in the extraMounts attribute of the config
# https://github.com/kubernetes-sigs/kind/issues/3642
export PATH_TO_HOST_DOCKER_CREDENTIALS=$HOME/.docker/config.json
envsubst < templates/kind_workload_config_template.yaml > generated/kind_workload_config.yaml
kind create cluster --name $WORKLOAD_K8S_CLUSTER_NAME_1 --config generated/kind_workload_config.yaml
kind create cluster --name $WORKLOAD_K8S_CLUSTER_NAME_2 --config generated/kind_workload_config.yaml

## Deploy workload identity infrastructure using cofidectl

rm -f cofide.yaml
cofidectl connect init \
  --connect-url $CONNECT_URL \
  --connect-trust-domain $CONNECT_TRUST_DOMAIN \
  --connect-bundle-host $CONNECT_BUNDLE_HOST \
  --authorization-domain $AUTHORIZATION_DOMAIN \
  --authorization-client-id $AUTHORIZATION_CLIENT_ID \
  --connect-datasource

cofidectl trust-zone add \
  $WORKLOAD_TRUST_ZONE_1 \
  --trust-domain $WORKLOAD_TRUST_DOMAIN_1 \
  --kubernetes-cluster $WORKLOAD_K8S_CLUSTER_NAME_1 \
  --kubernetes-context $WORKLOAD_K8S_CLUSTER_CONTEXT_1 \
  --profile kubernetes

cofidectl trust-zone add \
  $WORKLOAD_TRUST_ZONE_2 \
  --trust-domain $WORKLOAD_TRUST_DOMAIN_2 \
  --kubernetes-cluster $WORKLOAD_K8S_CLUSTER_NAME_2 \
  --kubernetes-context $WORKLOAD_K8S_CLUSTER_CONTEXT_2 \
  --profile kubernetes

cofidectl federation add \
  --trust-zone $WORKLOAD_TRUST_ZONE_1 \
  --remote-trust-zone $WORKLOAD_TRUST_ZONE_2

cofidectl federation add \
  --trust-zone $WORKLOAD_TRUST_ZONE_2 \
  --remote-trust-zone $WORKLOAD_TRUST_ZONE_1

cofidectl attestation-policy add kubernetes \
  --name $NAMESPACE-ns-$UNIQUE_ID \
  --namespace $NAMESPACE

cofidectl attestation-policy-binding add \
  --trust-zone $WORKLOAD_TRUST_ZONE_1 \
  --attestation-policy $NAMESPACE-ns-$UNIQUE_ID \
  --federates-with $WORKLOAD_TRUST_ZONE_2

cofidectl attestation-policy-binding add \
  --trust-zone $WORKLOAD_TRUST_ZONE_2 \
  --attestation-policy $NAMESPACE-ns-$UNIQUE_ID \
  --federates-with $WORKLOAD_TRUST_ZONE_1

cofidectl up --trust-zone $WORKLOAD_TRUST_ZONE_1 --trust-zone $WORKLOAD_TRUST_ZONE_2

## Validate the deployment using ping-pong demo

kubectl --context $WORKLOAD_K8S_CLUSTER_CONTEXT_1 create namespace $NAMESPACE
kubectl --context $WORKLOAD_K8S_CLUSTER_CONTEXT_2 create namespace $NAMESPACE

SERVER_CTX=$WORKLOAD_K8S_CLUSTER_CONTEXT_1
CLIENT_CTX=$WORKLOAD_K8S_CLUSTER_CONTEXT_2

export IMAGE_TAG=v0.1.10 # Version of cofide-demos to use
COFIDE_DEMOS_BRANCH="https://raw.githubusercontent.com/cofide/cofide-demos/refs/tags/$IMAGE_TAG"

SERVER_MANIFEST="$COFIDE_DEMOS_BRANCH/workloads/ping-pong/ping-pong-server/deploy.yaml"
export PING_PONG_SERVER_SERVICE_PORT=8443
if ! curl --fail $SERVER_MANIFEST | envsubst | kubectl apply -n "$NAMESPACE" --context "$SERVER_CTX" -f -; then
  echo "Error: Server deployment failed" >&2
  exit 1
fi
echo "Server deployment complete"

echo "Discovering server IP..."
kubectl --context "$SERVER_CTX" wait --for=jsonpath="{.status.loadBalancer.ingress[0].ip}" service/ping-pong-server -n $NAMESPACE --timeout=60s
export PING_PONG_SERVER_SERVICE_HOST=$(kubectl --context "$SERVER_CTX" get service ping-pong-server -n $NAMESPACE -o "jsonpath={.status.loadBalancer.ingress[0].ip}")
echo "Server is $PING_PONG_SERVER_SERVICE_HOST"

CLIENT_MANIFEST="$COFIDE_DEMOS_BRANCH/workloads/ping-pong/ping-pong-client/deploy.yaml"
if ! curl --fail $CLIENT_MANIFEST | envsubst | kubectl apply --context "$CLIENT_CTX" -n "$NAMESPACE" -f -; then
  echo "Error: client deployment failed" >&2
  exit 1
fi
echo "Client deployment complete"

kubectl --context $CLIENT_CTX wait -n $NAMESPACE --for=condition=Available --timeout 60s deployments/ping-pong-client
kubectl --context $CLIENT_CTX logs -n $NAMESPACE deployments/ping-pong-client -f
