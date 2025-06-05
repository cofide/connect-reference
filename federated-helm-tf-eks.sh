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
export CONNECT_URL
export CONNECT_TRUST_DOMAIN

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

export AWS_REGION
envsubst <templates/ebs-storageclass-template.yaml >generated/ebs-storageclass.yaml

# Create an EBS storageclass in each EKS cluster for the associated trust zone server.
kubectl apply -f generated/ebs-storageclass.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT_1
kubectl apply -f generated/ebs-storageclass.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT_2

# Applies the RBAC needed by the trust zone server in each EKS cluster.
kubectl apply -f templates/trust-zone-server-rbac.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT_1
kubectl apply -f templates/trust-zone-server-rbac.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT_2

## Register trust zones, clusters, attestation policies and federations in Connect using Terraform

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

export TF_VAR_attestation_policy_name="${NAMESPACE}-ns-${UNIQUE_ID}"
export TF_VAR_attestation_policy_namespace="${NAMESPACE}"

terraform -chdir=./terraform/federated init -input=false -backend=false

## Ensures that any resources from previous runs have been deleted first.
terraform -chdir=./terraform/federated destroy -input=false -auto-approve
terraform -chdir=./terraform/federated apply -input=false -auto-approve

# Deploy workload identity infrastructure using cofidectl to generate Helm values.

rm -f cofide.yaml
cofidectl connect init \
  --connect-url $CONNECT_URL \
  --connect-trust-domain $CONNECT_TRUST_DOMAIN \
  --connect-bundle-host $CONNECT_BUNDLE_HOST \
  --authorization-domain $AUTHORIZATION_DOMAIN \
  --authorization-client-id $AUTHORIZATION_CLIENT_ID

## Deploy SPIRE components using Helm

crds_chart_version="0.4.0"
chart_version="0.21.0"
chart_repo="https://spiffe.github.io/helm-charts-hardened/"
values_file_1=generated/spire-values-${WORKLOAD_TRUST_ZONE_1}.yaml
values_file_2=generated/spire-values-${WORKLOAD_TRUST_ZONE_2}.yaml

./cofidectl trust-zone helm values \
  $WORKLOAD_TRUST_ZONE_1 --output-file $values_file_1

./cofidectl trust-zone helm values \
  $WORKLOAD_TRUST_ZONE_2 --output-file $values_file_2

helm upgrade --install spire-crds spire-crds --repo $chart_repo --version $crds_chart_version \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT_1 --namespace spire-mgmt --create-namespace \
  --wait

helm upgrade --install spire-crds spire-crds --repo $chart_repo --version $crds_chart_version \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT_2 --namespace spire-mgmt --create-namespace \
  --wait

helm upgrade --install spire spire --repo $chart_repo --version $chart_version \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT_1 --namespace spire-mgmt --create-namespace \
  --values $values_file_1 --wait

helm upgrade --install spire spire --repo $chart_repo --version $chart_version \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT_2 --namespace spire-mgmt --create-namespace \
  --values $values_file_2 --wait

## Deploy Cofide agent using Helm

chart_version=0.1.3
chart_uri=oci://010438484483.dkr.ecr.eu-west-1.amazonaws.com/cofide/helm-charts/cofide-agent
values_file_1=generated/cofide-agent-values-${WORKLOAD_TRUST_ZONE_1}.yaml
values_file_2=generated/cofide-agent-values-${WORKLOAD_TRUST_ZONE_2}.yaml

./cofidectl connect agent helm values \
  --trust-zone $WORKLOAD_TRUST_ZONE_1 --cluster $WORKLOAD_K8S_CLUSTER_NAME_1 \
  --output-file $values_file_1 --generate-token=false

./cofidectl connect agent helm values \
  --trust-zone $WORKLOAD_TRUST_ZONE_2 --cluster $WORKLOAD_K8S_CLUSTER_NAME_2 \
  --output-file $values_file_2 --generate-token=false

token_1=$(./cofidectl connect agent join-token generate \
  --trust-zone $WORKLOAD_TRUST_ZONE_1 --cluster $WORKLOAD_K8S_CLUSTER_NAME_1 --output-file -)

token_2=$(./cofidectl connect agent join-token generate \
  --trust-zone $WORKLOAD_TRUST_ZONE_2 --cluster $WORKLOAD_K8S_CLUSTER_NAME_2 --output-file -)

helm upgrade --install cofide-agent $chart_uri --version $chart_version \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT_1 --namespace cofide --create-namespace \
  --values $values_file_1 --set agent.env.AGENT_TOKEN=$token_1 --wait

helm upgrade --install cofide-agent $chart_uri --version $chart_version \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT_2 --namespace cofide --create-namespace \
  --values $values_file_2 --set agent.env.AGENT_TOKEN=$token_2 --wait

## Validate the deployment using ping-pong demo

./ping-pong-demo.sh $WORKLOAD_K8S_CLUSTER_CONTEXT_1 $WORKLOAD_K8S_CLUSTER_CONTEXT_2
