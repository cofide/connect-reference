#!/bin/bash

set -euxo pipefail

# This script uses two existing EKS clusters and defines trust zones,
# clusters, an attestation policy, bindings and federations in the staging
# Connect using cofidectl and terraform-provider-cofide.
# It then runs a ping-pong test between the trust zones.

# Prerequisites: ./prerequisites.sh

source config.env

## Deploy workload cluster

source eks.env

export REGISTRY=010438484483.dkr.ecr.eu-west-1.amazonaws.com
export REPOSITORY=cofide/trust-zone-server
export TAG=v1.10.11
export CONNECT_URL=$CONNECT_URL
export CONNECT_TRUST_DOMAIN=$CONNECT_TRUST_DOMAIN

BUNDLE_ID=$(echo $CONNECT_TRUST_DOMAIN | cut -d '.' -f 1)
export CONNECT_BUNDLE_ENDPOINT_URL="https://$CONNECT_BUNDLE_HOST/$BUNDLE_ID/bundle"

# Generate unique ID for cluster, trust zone & trust domain disambiguation
UNIQUE_ID=$(uuidgen | head -c 8 | tr A-Z a-z)

export CLUSTER_NAME=$WORKLOAD_K8S_CLUSTER_NAME_1
export TRUST_DOMAIN=$WORKLOAD_TRUST_DOMAIN_1
envsubst < templates/trust-zone-server-values.yaml > generated/trust-zone-server-values-${WORKLOAD_TRUST_ZONE_1}.yaml

export CLUSTER_NAME=$WORKLOAD_K8S_CLUSTER_NAME_2
export TRUST_DOMAIN=$WORKLOAD_TRUST_DOMAIN_2
envsubst < templates/trust-zone-server-values.yaml > generated/trust-zone-server-values-${WORKLOAD_TRUST_ZONE_2}.yaml

envsubst <templates/ebs-storageclass-template.yaml >generated/ebs-storageclass.yaml

# Create an EBS storageclass in each EKS cluster for the associated trust zone server.
kubectl apply -f generated/ebs-storageclass.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT_1
kubectl apply -f generated/ebs-storageclass.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT_2

# Applies the RBAC needed by the trust zone server in each EKS cluster.
kubectl apply -f templates/trust-zone-server-rbac.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT_1
kubectl apply -f templates/trust-zone-server-rbac.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT_2

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

export TF_VAR_trust_zone_1_name="${WORKLOAD_TRUST_ZONE_1}"
export TF_VAR_trust_domain_1="${WORKLOAD_TRUST_DOMAIN_1}"
export TF_VAR_cluster_1_name="${WORKLOAD_K8S_CLUSTER_NAME_1}"
export TF_VAR_cluster_1_kubernetes_context="${WORKLOAD_K8S_CLUSTER_CONTEXT_1}"
export TF_VAR_cluster_1_extra_helm_values="$(realpath generated/trust-zone-server-values-${WORKLOAD_TRUST_ZONE_1}.yaml)"

export TF_VAR_trust_zone_2_name="${WORKLOAD_TRUST_ZONE_2}"
export TF_VAR_trust_domain_2="${WORKLOAD_TRUST_DOMAIN_2}"
export TF_VAR_cluster_2_name="${WORKLOAD_K8S_CLUSTER_NAME_2}"
export TF_VAR_cluster_2_kubernetes_context="${WORKLOAD_K8S_CLUSTER_CONTEXT_2}"
export TF_VAR_cluster_2_extra_helm_values="$(realpath generated/trust-zone-server-values-${WORKLOAD_TRUST_ZONE_2}.yaml)"

export TF_VAR_attestation_policy_name="${NAMESPACE-ns-$UNIQUE_ID}"
export TF_VAR_attestation_policy_namespace="${NAMESPACE}"

terraform -chdir=./terraform/federated init -input=false -backend=false

## Ensures that any resources from previous runs have been deleted first.
terraform -chdir=./terraform/federated destroy -input=false -auto-approve
terraform -chdir=./terraform/federated apply -input=false -auto-approve

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
kubectl --context "$SERVER_CTX" wait --for=jsonpath="{.status.loadBalancer.ingress[0].hostname}" service/ping-pong-server -n $NAMESPACE --timeout=60s
export PING_PONG_SERVER_SERVICE_HOST=$(kubectl --context "$SERVER_CTX" get service ping-pong-server -n $NAMESPACE -o "jsonpath={.status.loadBalancer.ingress[0].hostname}")
echo "Server is $PING_PONG_SERVER_SERVICE_HOST"

CLIENT_MANIFEST="$COFIDE_DEMOS_BRANCH/workloads/ping-pong/ping-pong-client/deploy.yaml"
if ! curl --fail $CLIENT_MANIFEST | envsubst | kubectl apply --context "$CLIENT_CTX" -n "$NAMESPACE" -f -; then
  echo "Error: client deployment failed" >&2
  exit 1
fi
echo "Client deployment complete"

kubectl --context $CLIENT_CTX wait -n $NAMESPACE --for=condition=Available --timeout 120s deployments/ping-pong-client
kubectl --context $CLIENT_CTX logs -n $NAMESPACE deployments/ping-pong-client -f
