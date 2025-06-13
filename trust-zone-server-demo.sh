#!/bin/bash

set -uo pipefail

# This script uses two existing EKS clusters and defines trust zones,
# clusters, an attestation policy, bindings and federations in the staging
# Connect using cofidectl and terraform-provider-cofide.
# It then runs a ping-pong test between the trust zones.

PAUSE=${PAUSE:-1}
source util.sh

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

WORKLOAD_TRUST_DOMAIN_1=$WORKLOAD_TRUST_DOMAIN_1-$UNIQUE_ID
WORKLOAD_TRUST_DOMAIN_2=$WORKLOAD_TRUST_DOMAIN_2-$UNIQUE_ID

export CLUSTER_NAME=$WORKLOAD_K8S_CLUSTER_NAME_1
export TRUST_DOMAIN=$WORKLOAD_TRUST_DOMAIN_1
envsubst < templates/trust-zone-server-values.yaml > generated/trust-zone-server-values-${WORKLOAD_TRUST_ZONE_1}.yaml

export CLUSTER_NAME=$WORKLOAD_K8S_CLUSTER_NAME_2
export TRUST_DOMAIN=$WORKLOAD_TRUST_DOMAIN_2
envsubst < templates/trust-zone-server-values.yaml > generated/trust-zone-server-values-${WORKLOAD_TRUST_ZONE_2}.yaml

## Register trust zones, clusters, attestation policies and federations in Connect using Terraform

set +x
ACCESS_TOKEN=$(grep 'cofide_access_token' ~/.cofide/credentials | cut -d'=' -f2)
if [ -z "${ACCESS_TOKEN}" ]; then
  echo "ERROR: Failed to get access token" >&2
  exit 1
fi
export COFIDE_API_TOKEN="${ACCESS_TOKEN}"
#set -x

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

announce "Registering trust zones, clusters, attestation policies and federations in Connect using Terraform"

run terraform -chdir=./terraform/federated init -input=false -backend=false

## Ensures that any resources from previous runs have been deleted first.
run terraform -chdir=./terraform/federated destroy -input=false -auto-approve
run terraform -chdir=./terraform/federated apply -input=false -auto-approve

pause

announce "Let's take a look at the created Connect resources using cofidectl"

rm -f cofide.yaml
run cofidectl connect init \
  --connect-url $CONNECT_URL \
  --connect-trust-domain $CONNECT_TRUST_DOMAIN \
  --connect-bundle-host $CONNECT_BUNDLE_HOST \
  --authorization-domain $AUTHORIZATION_DOMAIN \
  --authorization-client-id $AUTHORIZATION_CLIENT_ID

run cofidectl trust-zone list | tail -n 2
run cofidectl cluster list | tail -n 2
run cofidectl attestation-policy-binding list --trust-zone $WORKLOAD_TRUST_ZONE_1
run cofidectl attestation-policy-binding list --trust-zone $WORKLOAD_TRUST_ZONE_2
pause

announce "Deploying workload identity infrastructure to two empty EKS clusters"
run kubectl get pods -A --context $WORKLOAD_K8S_CLUSTER_CONTEXT_1
run kubectl get pods -A --context $WORKLOAD_K8S_CLUSTER_CONTEXT_2
pause

announce "Applying EBS storageclass"

export AWS_REGION
envsubst <templates/ebs-storageclass-template.yaml >generated/ebs-storageclass.yaml

# Create an EBS storageclass in each EKS cluster for the associated trust zone server.
run kubectl apply -f generated/ebs-storageclass.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT_1
run kubectl apply -f generated/ebs-storageclass.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT_2

pause

# Deploy workload identity infrastructure using cofidectl to generate Helm values.

## Deploy SPIRE components using Helm

crds_chart_version="0.4.0"
chart_version="0.21.0"
chart_repo="https://spiffe.github.io/helm-charts-hardened/"
values_file_1=generated/spire-values-${WORKLOAD_TRUST_ZONE_1}.yaml
values_file_2=generated/spire-values-${WORKLOAD_TRUST_ZONE_2}.yaml

announce "Deploying SPIRE components using Helm"

# Applies the RBAC needed by the trust zone server in each EKS cluster.
run kubectl apply -f templates/trust-zone-server-rbac.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT_1
run kubectl apply -f templates/trust-zone-server-rbac.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT_2

run cofidectl trust-zone helm values \
  $WORKLOAD_TRUST_ZONE_1 --output-file $values_file_1

run cofidectl trust-zone helm values \
  $WORKLOAD_TRUST_ZONE_2 --output-file $values_file_2

run helm upgrade --install spire-crds spire-crds --repo $chart_repo --version $crds_chart_version \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT_1 --namespace spire-mgmt --create-namespace \
  --wait

run helm upgrade --install spire-crds spire-crds --repo $chart_repo --version $crds_chart_version \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT_2 --namespace spire-mgmt --create-namespace \
  --wait

run helm upgrade --install spire spire --repo $chart_repo --version $chart_version \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT_1 --namespace spire-mgmt --create-namespace \
  --values $values_file_1 --wait

run helm upgrade --install spire spire --repo $chart_repo --version $chart_version \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT_2 --namespace spire-mgmt --create-namespace \
  --values $values_file_2 --wait

pause

## Deploy Cofide agent using Helm

chart_version=0.1.3
chart_uri=oci://010438484483.dkr.ecr.eu-west-1.amazonaws.com/cofide/helm-charts/cofide-agent
values_file_1=generated/cofide-agent-values-${WORKLOAD_TRUST_ZONE_1}.yaml
values_file_2=generated/cofide-agent-values-${WORKLOAD_TRUST_ZONE_2}.yaml

announce "Deploying Cofide Agent using Helm"

while [[ $(run cofidectl connect agent helm values --trust-zone $WORKLOAD_TRUST_ZONE_1 --cluster $WORKLOAD_K8S_CLUSTER_NAME_1 --output-file $values_file_1 --generate-token=false) == "Error: rpc error: code = Unauthenticated desc = Jwks remote fetch is failed" ]]; do
  sleep 1
done

run cofidectl connect agent helm values \
  --trust-zone $WORKLOAD_TRUST_ZONE_2 --cluster $WORKLOAD_K8S_CLUSTER_NAME_2 \
  --output-file $values_file_2 --generate-token=false

token_1=$(run cofidectl connect agent join-token generate \
  --trust-zone $WORKLOAD_TRUST_ZONE_1 --cluster $WORKLOAD_K8S_CLUSTER_NAME_1 --output-file -)

token_2=$(run cofidectl connect agent join-token generate \
  --trust-zone $WORKLOAD_TRUST_ZONE_2 --cluster $WORKLOAD_K8S_CLUSTER_NAME_2 --output-file -)

run helm upgrade --install cofide-agent $chart_uri --version $chart_version \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT_1 --namespace cofide --create-namespace \
  --values $values_file_1 --set agent.env.AGENT_TOKEN=$token_1 --wait

run helm upgrade --install cofide-agent $chart_uri --version $chart_version \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT_2 --namespace cofide --create-namespace \
  --values $values_file_2 --set agent.env.AGENT_TOKEN=$token_2 --wait

pause

PAUSE=0 announce "Waiting for Cofide Trust Zone Server to be ready"
run kubectl wait pods/spire-server-0 --for condition=Ready -n spire-server --context $WORKLOAD_K8S_CLUSTER_CONTEXT_1
run kubectl wait pods/spire-server-0 --for condition=Ready -n spire-server --context $WORKLOAD_K8S_CLUSTER_CONTEXT_2

PAUSE=0 announce "Deployed SPIRE components:"
run kubectl get pods -n spire-server --context $WORKLOAD_K8S_CLUSTER_CONTEXT_1
run kubectl get pods -n spire-system --context $WORKLOAD_K8S_CLUSTER_CONTEXT_1
run kubectl get pods -n spire-server --context $WORKLOAD_K8S_CLUSTER_CONTEXT_2
run kubectl get pods -n spire-system --context $WORKLOAD_K8S_CLUSTER_CONTEXT_2
pause

PAUSE=0 announce "Deployed Cofide agents:"
run kubectl get pods -n cofide --context $WORKLOAD_K8S_CLUSTER_CONTEXT_1
run kubectl get pods -n cofide --context $WORKLOAD_K8S_CLUSTER_CONTEXT_2
pause

announce "Cofide Trust Zone Server is using Connect as a datastore.\nSome state was populated using Terraform earlier.\nOther state such as the attested SPIRE agents is more dynamic, and managed by the Trust Zone Server"
# FIXME: Sometimes we see authentication failures - retry.
#until run cofidectl connect api call --service proto.connect.datastore_service.v1alpha1.DataStoreService --rpc ListAttestedNodes; do
  #sleep 1
#done
#pause

## Validate the deployment using ping-pong demo

announce "Validate the deployment using ping-pong demo"

run ./ping-pong-demo.sh $WORKLOAD_K8S_CLUSTER_CONTEXT_1 $WORKLOAD_K8S_CLUSTER_CONTEXT_2

read -p "Continue to Istio demo? (y/N) " input
if [[ $input == "y" ]]; then
	run ./multi-mesh-eks.sh $WORKLOAD_TRUST_DOMAIN_1 $WORKLOAD_TRUST_ZONE_1 $WORKLOAD_K8S_CLUSTER_CONTEXT_1
fi
