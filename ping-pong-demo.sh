#!/bin/bash

set -euxo pipefail

# This script runs a ping-pong demo workload from https://github.com/cofide/cofide-demos/.
# The ping-pong client and server communicate over SPIFFE mTLS.
# They may be in the same or different clusters and/or trust zones.
# Once the workloads are running, the script follows the client's logs.
# Hit Ctrl-C to exit once you see the following output:
# ping...
# ...pong

source config.env

SERVER_CTX=${1?Server context}
CLIENT_CTX=${2?Client context}
 
kubectl --context $SERVER_CTX create namespace $NAMESPACE || true
kubectl --context $CLIENT_CTX create namespace $NAMESPACE || true

export IMAGE_TAG=v0.2.3 # Version of cofide-demos to use
COFIDE_DEMOS_BRANCH="https://raw.githubusercontent.com/cofide/cofide-demos/refs/tags/$IMAGE_TAG"

SERVER_MANIFEST="$COFIDE_DEMOS_BRANCH/workloads/ping-pong/ping-pong-server/deploy.yaml"
export PING_PONG_SERVER_SERVICE_PORT=8443
if ! curl --fail $SERVER_MANIFEST | envsubst | kubectl apply -n "$NAMESPACE" --context "$SERVER_CTX" -f -; then
  echo "Error: Server deployment failed" >&2
  exit 1
fi
echo "Server deployment complete"

if [[ $SERVER_CTX = $CLIENT_CTX ]]; then
  export PING_PONG_SERVER_SERVICE_HOST=ping-pong-server
else
  echo "Discovering server address..."
  # Assume that services have a hostname on EKS, or an IP elsewhere.
  if [[ $SERVER_CTX =~ arn:* ]]; then
    SVC_FIELD="hostname"
  else
    SVC_FIELD="ip"
  fi
  kubectl --context "$SERVER_CTX" wait --for=jsonpath="{.status.loadBalancer.ingress[0].${SVC_FIELD}}" service/ping-pong-server -n $NAMESPACE --timeout=60s
  export PING_PONG_SERVER_SERVICE_HOST=$(kubectl --context "$SERVER_CTX" get service ping-pong-server -n $NAMESPACE -o "jsonpath={.status.loadBalancer.ingress[0].${SVC_FIELD}}")
  echo "Server is $PING_PONG_SERVER_SERVICE_HOST"
  if [[ $SERVER_CTX =~ arn:* ]]; then
    echo "Waiting for ping-pong service hostname to resolve..."
    while ! nslookup $PING_PONG_SERVER_SERVICE_HOST &>/dev/null; do
      sleep 2
    done
  fi
fi

CLIENT_MANIFEST="$COFIDE_DEMOS_BRANCH/workloads/ping-pong/ping-pong-client/deploy.yaml"
if ! curl --fail $CLIENT_MANIFEST | envsubst | kubectl apply --context "$CLIENT_CTX" -n "$NAMESPACE" -f -; then
  echo "Error: client deployment failed" >&2
  exit 1
fi
echo "Client deployment complete"

kubectl --context $CLIENT_CTX wait -n $NAMESPACE --for=condition=Available --timeout 120s deployments/ping-pong-client
kubectl --context $CLIENT_CTX logs -n $NAMESPACE deployments/ping-pong-client -f
