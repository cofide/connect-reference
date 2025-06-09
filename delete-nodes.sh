#!/bin/bash

set -ux

# This script deletes stale SPIRE node entries in the Connect datastore.
# This should be performed after tearing down a SPIRE stack in a k8s cluster in which SPIRE will be redeployed.
# This should not be necessary if Connect has this change: https://github.com/cofide/cofide-connect/pull/907
# Currently the SPIFFE IDs of the nodes are hard-coded.
# Use the following command to look for stale nodes in the trust zone, and add their IDs here.
# cofidectl connect api call --service proto.connect.datastore_service.v1alpha1.DataStoreService --rpc ListAttestedNodes

nodes="spiffe://mg-workload-1.test/spire/agent/k8s_psat/mg-workload-1/8c20f510-50aa-4d52-aa75-4af26798f782 spiffe://mg-workload-2.test/spire/agent/k8s_psat/mg-workload-2/c0f399e9-a2fd-4689-aeab-bc8e2eb003db spiffe://mg-workload-2.test/spire/agent/k8s_psat/mg-workload-2/7756531b-bd21-49ef-8a36-1e90c760a26a"

for node in $nodes; do
  echo "Deleting $node"
  ./cofidectl connect api call \
    --service proto.connect.datastore_service.v1alpha1.DataStoreService \
    --rpc DeleteAttestedNode \
    --data '{"spiffe_id": "'$node'"}'
done
