#!/bin/bash

set -euxo pipefail

# This script uses an existing EKS cluster and defines a trust zone, cluster,
# attestation policy and binding in the staging Connect using cofidectl. It
# then runs a ping-pong test.

# Prerequisites: ./prerequisites.sh

source config.env

## Deploy workload cluster

# Generate unique ID for cluster, trust zone & trust domain disambiguation
UNIQUE_ID=$(uuidgen | head -c 8 | tr A-Z a-z)

source eks.env

# Create an EBS storageclass for SPIRE server.

AWS_REGION=eu-west-1 envsubst <templates/ebs-storageclass-template.yaml >generated/ebs-storageclass.yaml
kubectl --context $WORKLOAD_K8S_CLUSTER_CONTEXT apply -f generated/ebs-storageclass.yaml

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
  $WORKLOAD_TRUST_ZONE \
  --trust-domain $WORKLOAD_TRUST_DOMAIN \
  --kubernetes-cluster $WORKLOAD_K8S_CLUSTER_NAME \
  --kubernetes-context $WORKLOAD_K8S_CLUSTER_CONTEXT \
  --profile kubernetes

cofidectl attestation-policy add kubernetes \
  --name $NAMESPACE-ns-$WORKLOAD_TRUST_ZONE \
  --namespace $NAMESPACE

cofidectl attestation-policy-binding add \
  --trust-zone $WORKLOAD_TRUST_ZONE \
  --attestation-policy $NAMESPACE-ns-$WORKLOAD_TRUST_ZONE

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
