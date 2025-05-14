#!/bin/bash

set -euxo pipefail

# This script creates a kind cluster and defines a trust zone, cluster,
# attestation policy and binding in the staging Connect using cofidectl. It
# then runs a ping-pong test.

# Prerequisites: ./prerequisites.sh

source config.env

## deploy_user.sh

# Generate unique ID for cluster, trust zone & trust domain disambiguation
UNIQUE_ID=$(uuidgen | head -c 8 | tr A-Z a-z)

USER_K8S_CLUSTER_NAME="${USER_K8S_CLUSTER_NAME:-user-${UNIQUE_ID}}"
USER_K8S_CLUSTER_CONTEXT="${USER_K8S_CLUSTER_CONTEXT:-kind-user-${UNIQUE_ID}}"
# Trust zones must be unique within a single Cofide Connect service.
USER_TRUST_ZONE=${USER_TRUST_ZONE:-${UNIQUE_ID}}
# Trust domains must currently be globally unique due to a shared S3 bucket for hosting bundles.
USER_TRUST_DOMAIN=${USER_TRUST_DOMAIN:-${UNIQUE_ID}.test}

kind delete cluster --name $USER_K8S_CLUSTER_NAME

# Patch in host Docker config in order to enable pulling images
# to the Kind cluster. This envsubst approach is required as Kind does
# not support ~ or $HOME directly in the extraMounts attribute of the config
# https://github.com/kubernetes-sigs/kind/issues/3642
export PATH_TO_HOST_DOCKER_CREDENTIALS=$HOME/.docker/config.json
envsubst < templates/kind_user_config_template.yaml > generated/kind_user_config.yaml
kind create cluster --name $USER_K8S_CLUSTER_NAME --config generated/kind_user_config.yaml

## cofidectl_up.sh

rm -f cofide.yaml
cofidectl connect init \
  --connect-url $CONNECT_URL \
  --connect-trust-domain $CONNECT_TRUST_DOMAIN \
  --connect-bundle-host $CONNECT_BUNDLE_HOST \
  --authorization-domain $AUTHORIZATION_DOMAIN \
  --authorization-client-id $AUTHORIZATION_CLIENT_ID \
  --connect-datasource

cofidectl trust-zone add \
  $USER_TRUST_ZONE \
  --trust-domain $USER_TRUST_DOMAIN \
  --kubernetes-cluster $USER_K8S_CLUSTER_NAME \
  --kubernetes-context $USER_K8S_CLUSTER_CONTEXT \
  --profile kubernetes

cofidectl attestation-policy add kubernetes \
  --name $NAMESPACE-ns-$USER_TRUST_ZONE \
  --namespace $NAMESPACE

cofidectl attestation-policy-binding add \
  --trust-zone $USER_TRUST_ZONE \
  --attestation-policy $NAMESPACE-ns-$USER_TRUST_ZONE

cofidectl up --trust-zone $USER_TRUST_ZONE

## create_namespace.sh

kubectl --context $USER_K8S_CLUSTER_CONTEXT create namespace $NAMESPACE

## deploy_ping_pong.sh

SERVER_CTX=$USER_K8S_CLUSTER_CONTEXT
CLIENT_CTX=$USER_K8S_CLUSTER_CONTEXT

export IMAGE_TAG=v0.1.3 # Version of cofide-demos to use
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
