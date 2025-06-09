#!/bin/bash

set -euxo pipefail

# This script creates a pair of kind clusters and defines trust zones,
# clusters, an attestation policy, bindings and federations in the staging
# Connect using cofidectl and terraform-provider-cofide.
# It then runs a ping-pong test between the trust zones, each using the Cofide trust zone server.

# Prerequisites: ./prerequisites.sh

source config.env

## Deploy workload cluster

export REGISTRY=010438484483.dkr.ecr.eu-west-1.amazonaws.com
export REPOSITORY=cofide/trust-zone-server
export TAG=v1.10.11
export CONNECT_URL
export CONNECT_TRUST_DOMAIN

BUNDLE_ID=$(echo $CONNECT_TRUST_DOMAIN | cut -d '.' -f 1)
export CONNECT_BUNDLE_ENDPOINT_URL="https://$CONNECT_BUNDLE_HOST/$BUNDLE_ID/bundle"

# Generate unique ID for cluster, trust zone & trust domain disambiguation
UNIQUE_ID=$(uuidgen | head -c 8 | tr A-Z a-z)

WORKLOAD_K8S_CLUSTER_NAME_1="workload-${UNIQUE_ID}-1"
WORKLOAD_K8S_CLUSTER_CONTEXT_1="kind-workload-${UNIQUE_ID}-1"
# Trust zones must be unique within a single Cofide Connect service.
WORKLOAD_TRUST_ZONE_1="${UNIQUE_ID}-1"
# Trust domains must currently be globally unique due to a shared S3 bucket for hosting bundles.
WORKLOAD_TRUST_DOMAIN_1="${UNIQUE_ID}-1.test"

export CLUSTER_NAME=$WORKLOAD_K8S_CLUSTER_NAME_1
export TRUST_DOMAIN=$WORKLOAD_TRUST_DOMAIN_1

envsubst < templates/trust-zone-server-values.yaml > generated/trust-zone-server-values-${WORKLOAD_TRUST_ZONE_1}.yaml

WORKLOAD_K8S_CLUSTER_NAME_2="workload-${UNIQUE_ID}-2"
WORKLOAD_K8S_CLUSTER_CONTEXT_2="kind-workload-${UNIQUE_ID}-2"
# Trust zones must be unique within a single Cofide Connect service.
WORKLOAD_TRUST_ZONE_2="${UNIQUE_ID}-2"
# Trust domains must currently be globally unique due to a shared S3 bucket for hosting bundles.
WORKLOAD_TRUST_DOMAIN_2="${UNIQUE_ID}-2.test"

export CLUSTER_NAME=$WORKLOAD_K8S_CLUSTER_NAME_2
export TRUST_DOMAIN=$WORKLOAD_TRUST_DOMAIN_2

envsubst < templates/trust-zone-server-values.yaml > generated/trust-zone-server-values-${WORKLOAD_TRUST_ZONE_2}.yaml

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

# Applies the RBAC needed by the trust zone server in each Kind cluster.
kubectl apply -f templates/trust-zone-server-rbac.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT_1
kubectl apply -f templates/trust-zone-server-rbac.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT_2

## Deploy workload identity infrastructure using cofidectl and terraform-provider-cofide

rm -f cofide.yaml
cofidectl connect init \
  --connect-url $CONNECT_URL \
  --connect-trust-domain $CONNECT_TRUST_DOMAIN \
  --connect-bundle-host $CONNECT_BUNDLE_HOST \
  --authorization-domain $AUTHORIZATION_DOMAIN \
  --authorization-client-id $AUTHORIZATION_CLIENT_ID

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

export TF_VAR_trust_zone_1_name="${WORKLOAD_TRUST_ZONE_1}"
export TF_VAR_trust_domain_1="${WORKLOAD_TRUST_DOMAIN_1}"
export TF_VAR_cluster_1_name="${WORKLOAD_K8S_CLUSTER_NAME_1}"
export TF_VAR_cluster_1_kubernetes_context="${WORKLOAD_K8S_CLUSTER_CONTEXT_1}"
export TF_VAR_cluster_1_extra_helm_values="$(realpath generated/trust-zone-server-values-${WORKLOAD_TRUST_ZONE_1}.yaml)"

export TF_VAR_attestation_policy_name="${NAMESPACE}-ns-${UNIQUE_ID}"
export TF_VAR_attestation_policy_namespace="${NAMESPACE}"

export TF_VAR_trust_zone_2_name="${WORKLOAD_TRUST_ZONE_2}"
export TF_VAR_trust_domain_2="${WORKLOAD_TRUST_DOMAIN_2}"
export TF_VAR_cluster_2_name="${WORKLOAD_K8S_CLUSTER_NAME_2}"
export TF_VAR_cluster_2_extra_helm_values="$(realpath generated/trust-zone-server-values-${WORKLOAD_TRUST_ZONE_2}.yaml)"
export TF_VAR_cluster_2_kubernetes_context="${WORKLOAD_K8S_CLUSTER_CONTEXT_2}"

terraform -chdir=./terraform/federated init -input=false -backend=false

## Ensures that any resources from previous runs have been deleted first.
terraform -chdir=./terraform/federated destroy -input=false -auto-approve
terraform -chdir=./terraform/federated apply -input=false -auto-approve

cofidectl up --trust-zone $WORKLOAD_TRUST_ZONE_1 --trust-zone $WORKLOAD_TRUST_ZONE_2

## Validate the deployment using ping-pong demo

./ping-pong-demo.sh $WORKLOAD_K8S_CLUSTER_CONTEXT_1 $WORKLOAD_K8S_CLUSTER_CONTEXT_2
