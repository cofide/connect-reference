#!/bin/bash

set -euxo pipefail

# This script creates a pair of kind clusters with Istio installed, and defines
# trust zones, clusters, an attestation policy, bindings and federations in the
# staging Connect using cofidectl. It then creates a federated service and runs
# a ping-pong test between the trust zones.

# Prerequisites: ./prerequisites.sh

source config.env

if ! command -v $HOME/.istioctl/bin/istioctl && ! type istioctl; then
  curl -sL https://istio.io/downloadIstioctl | sh -
  export PATH=$HOME/.istioctl/bin:$PATH
fi

## Deploy workload clusters

# Generate unique ID for cluster, trust zone & trust domain disambiguation
UNIQUE_ID=$(uuidgen | head -c 8 | tr A-Z a-z)

USER_K8S_CLUSTER_NAME_1="user-${UNIQUE_ID}-1"
USER_K8S_CLUSTER_CONTEXT_1="kind-user-${UNIQUE_ID}-1"
# Trust zones must be unique within a single Cofide Connect service.
USER_TRUST_ZONE_1="${UNIQUE_ID}-1"
# Trust domains must currently be globally unique due to a shared S3 bucket for hosting bundles.
USER_TRUST_DOMAIN_1="${UNIQUE_ID}-1.test"

USER_K8S_CLUSTER_NAME_2="user-${UNIQUE_ID}-2"
USER_K8S_CLUSTER_CONTEXT_2="kind-user-${UNIQUE_ID}-2"
# Trust zones must be unique within a single Cofide Connect service.
USER_TRUST_ZONE_2="${UNIQUE_ID}-2"
# Trust domains must currently be globally unique due to a shared S3 bucket for hosting bundles.
USER_TRUST_DOMAIN_2="${UNIQUE_ID}-2.test"

kind delete cluster --name $USER_K8S_CLUSTER_NAME_1
kind delete cluster --name $USER_K8S_CLUSTER_NAME_2

# Patch in host Docker config in order to enable pulling images
# to the Kind cluster. This envsubst approach is required as Kind does
# not support ~ or $HOME directly in the extraMounts attribute of the config
# https://github.com/kubernetes-sigs/kind/issues/3642
export PATH_TO_HOST_DOCKER_CREDENTIALS=$HOME/.docker/config.json
envsubst <templates/kind_user_config_template.yaml >generated/kind_user_config.yaml
kind create cluster --name $USER_K8S_CLUSTER_NAME_1 --config generated/kind_user_config.yaml
kind create cluster --name $USER_K8S_CLUSTER_NAME_2 --config generated/kind_user_config.yaml

## Install Istio

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml --context $USER_K8S_CLUSTER_CONTEXT_1
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml --context $USER_K8S_CLUSTER_CONTEXT_2

export HOST_TRUST_DOMAIN=$USER_TRUST_DOMAIN_1
export OTHER_TRUST_DOMAINS="[$USER_TRUST_DOMAIN_2]"
export CLUSTER=$USER_K8S_CLUSTER_NAME_1
envsubst <templates/istio-meshconfig-template.yaml >generated/istio-meshconfig-$USER_TRUST_ZONE_1.yaml
istioctl install --skip-confirmation -f generated/istio-meshconfig-$USER_TRUST_ZONE_1.yaml --context $USER_K8S_CLUSTER_CONTEXT_1

export HOST_TRUST_DOMAIN=$USER_TRUST_DOMAIN_2
export OTHER_TRUST_DOMAINS="[$USER_TRUST_DOMAIN_1]"
export CLUSTER=$USER_K8S_CLUSTER_NAME_2
envsubst <templates/istio-meshconfig-template.yaml >generated/istio-meshconfig-$USER_TRUST_ZONE_2.yaml
istioctl install --skip-confirmation -f generated/istio-meshconfig-$USER_TRUST_ZONE_2.yaml --context $USER_K8S_CLUSTER_CONTEXT_2

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
  $USER_TRUST_ZONE_1 \
  --trust-domain $USER_TRUST_DOMAIN_1 \
  --kubernetes-cluster $USER_K8S_CLUSTER_NAME_1 \
  --kubernetes-context $USER_K8S_CLUSTER_CONTEXT_1 \
  --profile istio

cofidectl trust-zone add \
  $USER_TRUST_ZONE_2 \
  --trust-domain $USER_TRUST_DOMAIN_2 \
  --kubernetes-cluster $USER_K8S_CLUSTER_NAME_2 \
  --kubernetes-context $USER_K8S_CLUSTER_CONTEXT_2 \
  --profile istio

cofidectl federation add \
  --trust-zone $USER_TRUST_ZONE_1 \
  --remote-trust-zone $USER_TRUST_ZONE_2

cofidectl federation add \
  --trust-zone $USER_TRUST_ZONE_2 \
  --remote-trust-zone $USER_TRUST_ZONE_1

cofidectl attestation-policy add kubernetes \
  --name $NAMESPACE-ns-$UNIQUE_ID \
  --namespace $NAMESPACE

cofidectl attestation-policy-binding add \
  --trust-zone $USER_TRUST_ZONE_1 \
  --attestation-policy $NAMESPACE-ns-$UNIQUE_ID \
  --federates-with $USER_TRUST_ZONE_2

cofidectl attestation-policy-binding add \
  --trust-zone $USER_TRUST_ZONE_2 \
  --attestation-policy $NAMESPACE-ns-$UNIQUE_ID \
  --federates-with $USER_TRUST_ZONE_1

cofidectl up --trust-zone $USER_TRUST_ZONE_1 --trust-zone $USER_TRUST_ZONE_2

# Create an Istio gateway.

SERVER_TRUST_ZONE=$USER_TRUST_ZONE_1 envsubst <templates/gateway-template.yaml >generated/gateway.yaml
kubectl apply -f generated/gateway.yaml --context $USER_K8S_CLUSTER_CONTEXT_1

# Create a federated service.

export NAMESPACE
export FEDERATED_SERVICE_NAME=server
export CLIENT_TRUST_ZONE=$USER_TRUST_ZONE_2
export WORKLOAD_LABEL_APP=ping-pong-server
export SERVER_PORT=8443
envsubst <templates/federated-service-template.yaml >generated/federated-service.yaml
kubectl --context $USER_K8S_CLUSTER_CONTEXT_1 apply -f generated/federated-service.yaml

## Validate the deployment using ping-pong demo

kubectl --context $USER_K8S_CLUSTER_CONTEXT_2 create namespace $NAMESPACE

SERVER_CTX=$USER_K8S_CLUSTER_CONTEXT_1
CLIENT_CTX=$USER_K8S_CLUSTER_CONTEXT_2

export IMAGE_TAG=v0.1.10 # Version of cofide-demos to use
COFIDE_DEMOS_BRANCH="https://raw.githubusercontent.com/cofide/cofide-demos/refs/tags/$IMAGE_TAG"

SERVER_MANIFEST="$COFIDE_DEMOS_BRANCH/workloads/ping-pong-mesh/ping-pong-mesh-server/deploy.yaml"
export PING_PONG_SERVER_SERVICE_PORT=8443
export PING_PONG_SERVER_SERVICE_HOST=server.${NAMESPACE}.${USER_TRUST_ZONE_1}.test
if ! curl --fail $SERVER_MANIFEST | envsubst | kubectl apply -n "$NAMESPACE" --context "$SERVER_CTX" -f -; then
  echo "Error: Server deployment failed" >&2
  exit 1
fi
echo "Server deployment complete"

CLIENT_MANIFEST="$COFIDE_DEMOS_BRANCH/workloads/ping-pong-mesh/ping-pong-mesh-client/deploy.yaml"
if ! curl --fail $CLIENT_MANIFEST | envsubst | kubectl apply --context "$CLIENT_CTX" -n "$NAMESPACE" -f -; then
  echo "Error: client deployment failed" >&2
  exit 1
fi
echo "Client deployment complete"

kubectl --context $CLIENT_CTX wait -n $NAMESPACE --for=condition=Available --timeout 120s deployments/ping-pong-client
kubectl --context $CLIENT_CTX logs -n $NAMESPACE deployments/ping-pong-client -f
