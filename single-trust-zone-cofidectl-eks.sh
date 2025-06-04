#!/bin/bash

set -euxo pipefail

# This script uses an existing EKS cluster and defines a trust zone, cluster,
# attestation policy and binding in the staging Connect using cofidectl. It
# then runs a ping-pong test.

# Prerequisites: ./prerequisites.sh

source config.env

## Deploy workload cluster

source eks.env

# Create an EBS storageclass for SPIRE server.

export AWS_REGION
envsubst <templates/ebs-storageclass-template.yaml >generated/ebs-storageclass.yaml
kubectl --context $WORKLOAD_K8S_CLUSTER_CONTEXT_1 apply -f generated/ebs-storageclass.yaml

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
  $WORKLOAD_TRUST_ZONE_1 \
  --trust-domain $WORKLOAD_TRUST_DOMAIN_1 \
  --kubernetes-cluster $WORKLOAD_K8S_CLUSTER_NAME_1 \
  --kubernetes-context $WORKLOAD_K8S_CLUSTER_CONTEXT_1 \
  --profile kubernetes

cofidectl attestation-policy add kubernetes \
  --name $NAMESPACE-ns-$WORKLOAD_TRUST_ZONE_1 \
  --namespace $NAMESPACE

cofidectl attestation-policy-binding add \
  --trust-zone $WORKLOAD_TRUST_ZONE_1 \
  --attestation-policy $NAMESPACE-ns-$WORKLOAD_TRUST_ZONE_1

cofidectl up --trust-zone $WORKLOAD_TRUST_ZONE_1

## Validate the deployment using ping-pong demo

./ping-pong-demo.sh $WORKLOAD_K8S_CLUSTER_CONTEXT_1 $WORKLOAD_K8S_CLUSTER_CONTEXT_1
