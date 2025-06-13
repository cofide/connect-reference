#!/bin/bash

set -uo pipefail

# This script provisions Istio onto a third EKS cluster and deploys
# a ping-pong pair (via the SDK DNS routing) between this cluster and
# another EKS cluster without Istio

PAUSE=${PAUSE:-1}
source util.sh
source config.env
source eks.env

# Non-Istio cluster details to deploy client to
OTHER_TRUST_DOMAIN=${1?Other trust domain}
OTHER_TRUST_ZONE=${2?Other trust zone}
OTHER_CONTEXT=${3?Other context}

WORKLOAD_K8S_CLUSTER_NAME="demo-workload-c"
WORKLOAD_K8S_CLUSTER_CONTEXT="arn:aws:eks:${AWS_REGION}:${AWS_ACCOUNT}:cluster/$WORKLOAD_K8S_CLUSTER_NAME"
WORKLOAD_TRUST_ZONE="$WORKLOAD_K8S_CLUSTER_NAME"
WORKLOAD_TRUST_DOMAIN="$WORKLOAD_K8S_CLUSTER_NAME.test"

UNIQUE_ID=$(uuidgen | head -c 8 | tr A-Z a-z)
WORKLOAD_TRUST_DOMAIN=$WORKLOAD_TRUST_DOMAIN-$UNIQUE_ID

announce "Deploying Istio resources" 

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT
envsubst <templates/istio-meshconfig-template.yaml >generated/istio-meshconfig-$WORKLOAD_TRUST_DOMAIN.yaml
istioctl install --skip-confirmation -f generated/istio-meshconfig-$WORKLOAD_TRUST_DOMAIN.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT

# Create an EBS storageclass in each EKS cluster for the associated trust zone server.
kubectl apply -f generated/ebs-storageclass.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT

cofidectl trust-zone add \
  $WORKLOAD_TRUST_ZONE \
  --trust-domain $WORKLOAD_TRUST_DOMAIN \
  --kubernetes-cluster $WORKLOAD_K8S_CLUSTER_NAME \
  --kubernetes-context $WORKLOAD_K8S_CLUSTER_CONTEXT \
  --profile istio

cofidectl federation add \
  --trust-zone $WORKLOAD_TRUST_ZONE \
  --remote-trust-zone $OTHER_TRUST_ZONE

cofidectl federation add \
  --trust-zone $OTHER_TRUST_ZONE \
  --remote-trust-zone $WORKLOAD_TRUST_ZONE

cofidectl attestation-policy add kubernetes \
  --name $NAMESPACE-ns-$UNIQUE_ID \
  --namespace $NAMESPACE

cofidectl attestation-policy-binding add \
  --trust-zone $WORKLOAD_TRUST_ZONE \
  --attestation-policy $NAMESPACE-ns-$UNIQUE_ID \
  --federates-with $OTHER_TRUST_ZONE

cofidectl attestation-policy-binding add \
  --trust-zone $OTHER_TRUST_ZONE \
  --attestation-policy $NAMESPACE-ns-$UNIQUE_ID \
  --federates-with $WORKLOAD_TRUST_ZONE

crds_chart_version="0.4.0"
chart_version="0.21.0"
chart_repo="https://spiffe.github.io/helm-charts-hardened/"
values_file=generated/spire-values-${WORKLOAD_TRUST_ZONE}.yaml

cofidectl trust-zone helm values \
  $WORKLOAD_TRUST_ZONE --output-file $values_file

helm upgrade --install spire-crds spire-crds --repo $chart_repo --version $crds_chart_version \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT --namespace spire-mgmt --create-namespace \
  --wait

helm upgrade --install spire spire --repo $chart_repo --version $chart_version \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT --namespace spire-mgmt --create-namespace \
  --values $values_file --wait

pause

chart_version=0.1.3
chart_uri=oci://010438484483.dkr.ecr.eu-west-1.amazonaws.com/cofide/helm-charts/cofide-agent
values_file=generated/cofide-agent-values-${WORKLOAD_TRUST_ZONE}.yaml

while [[ $(cofidectl connect agent helm values --trust-zone $WORKLOAD_TRUST_ZONE --cluster $WORKLOAD_K8S_CLUSTER_NAME --output-file $values_file --generate-token=false) == "Error: rpc error: code = Unauthenticated desc = Jwks remote fetch is failed" ]]; do
  sleep 1
done

token=$(cofidectl connect agent join-token generate \
  --trust-zone $WORKLOAD_TRUST_ZONE --cluster $WORKLOAD_K8S_CLUSTER_NAME --output-file -)

helm upgrade --install cofide-agent $chart_uri --version $chart_version \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT --namespace cofide --create-namespace \
  --values $values_file --set agent.env.AGENT_TOKEN=$token --wait

kubectl apply -f ./templates/production-namespace.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT

helm repo add jetstack https://charts.jetstack.io --force-update --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT
helm repo update --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT

helm upgrade --install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.17.1 \
  --set crds.enabled=true \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT

kubectl apply -f ./templates/cert-manager-issuer.yaml --context $WORKLOAD_K8S_CLUSTER_CONTEXT

helm upgrade --install --namespace cofide \
  spiffe-enable \
  cofide/spiffe-enable \
  --kube-context $WORKLOAD_K8S_CLUSTER_CONTEXT \
  --set image.tag="0.2.1"

announce "Deploying ping-pong workloads"

export IMAGE_TAG=v0.1.10
BRANCH="https://raw.githubusercontent.com/cofide/cofide-demos/refs/tags/$IMAGE_TAG"
MANIFEST="$BRANCH/workloads/ping-pong-cofide/ping-pong-cofide-server/deploy.yaml"
cat ./templates/ping-pong-cofide-server.yaml | envsubst | kubectl apply -n production -f - --context $WORKLOAD_K8S_CLUSTER_CONTEXT

export IMAGE_TAG=v0.1.10
export PING_PONG_SERVER_SERVICE_PORT=8443
export PING_PONG_SERVER_SERVICE_HOST="server.production.$WORKLOAD_TRUST_DOMAIN"
export EXPERIMENTAL_XDS_SERVER_URI=cofide-agent-xds.cofide.svc.cluster.local:18001

BRANCH="https://raw.githubusercontent.com/cofide/cofide-demos/refs/tags/$IMAGE_TAG"
MANIFEST="$BRANCH/workloads/ping-pong-cofide/ping-pong-cofide-client/deploy.yaml"
curl --fail $MANIFEST | envsubst | kubectl apply -n production -f - --context $OTHER_CONTEXT

announce "Deploying FederatedService"

export OTHER_TRUST_DOMAIN
cat ./templates/federated-service.yaml | envsubst | yq 
cat ./templates/federated-service.yaml | envsubst | kubectl apply -n production -f - --context $WORKLOAD_K8S_CLUSTER_CONTEXT
