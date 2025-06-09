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
  --authorization-client-id $AUTHORIZATION_CLIENT_ID

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

./ping-pong-demo.sh $WORKLOAD_K8S_CLUSTER_CONTEXT_1 $WORKLOAD_K8S_CLUSTER_CONTEXT_2
