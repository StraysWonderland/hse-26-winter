#!/usr/bin/env bash
# Remove demo workloads. DELETE_CLUSTER=1 also deletes the dedicated kind cluster.
source "$(dirname "$0")/lib.sh"

if [[ "${DELETE_CLUSTER:-0}" == 1 ]]; then
  kind delete cluster --name "$CLUSTER"
  echo "deleted kind cluster $CLUSTER"
  exit 0
fi

require_cluster
$K delete namespace todo --ignore-not-found --wait=true
echo "deleted namespace todo (cluster $CLUSTER is still running)"

