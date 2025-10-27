#!/bin/bash

set -euxo pipefail

# This script creates a kind cluster and defines a trust zone, cluster,
# attestation policy and binding in the staging Connect using cofidectl. It
# then runs a ping-pong test.

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

## Deploy workload identity infrastructure using cofidectl

rm -f cofide.yaml
cofidectl connect init \
  --connect-url $CONNECT_URL \
  --connect-trust-domain $CONNECT_TRUST_DOMAIN \
  --connect-bundle-host $CONNECT_BUNDLE_HOST \
  --authorization-domain $AUTHORIZATION_DOMAIN \
  --authorization-client-id $AUTHORIZATION_CLIENT_ID \
  --use-oss-spire

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

./ping-pong-demo.sh $WORKLOAD_K8S_CLUSTER_CONTEXT $WORKLOAD_K8S_CLUSTER_CONTEXT
