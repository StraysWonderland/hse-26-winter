#!/usr/bin/env bash
# Helpers for the live demo. Commands pause for Enter; AUTO=1 runs without pauses.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
DEMO=$ROOT/scripts/07-kubernetes
K8S=$ROOT/k8s
POSTGRES_K8S=$ROOT/infra/postgres/k8s
NATS_K8S=$ROOT/infra/nats/k8s
TODO_K8S=$ROOT/services/todo-service/k8s
ACTIVITY_K8S=$ROOT/services/activity-service/k8s
FRONTEND_K8S=$ROOT/services/frontend/k8s
CLUSTER=todo-lecture
CONTEXT=kind-$CLUSTER
cd "$ROOT"

if [[ -t 1 ]]; then B=$'\e[1m'; C=$'\e[36m'; Y=$'\e[33m'; N=$'\e[0m'; else B= C= Y= N=; fi

step() { printf '\n%s## %s%s\n' "$C" "$*" "$N"; }
note() { printf '%s> %s%s\n' "$Y" "$*" "$N"; }
pause() { [[ "${AUTO:-0}" == 1 ]] && { echo; return; }; read -r _ </dev/tty; }
run() { printf '%s$ %s%s' "$B" "$*" "$N"; pause; eval "$@"; }

require_cluster() {
  kubectl config get-contexts "$CONTEXT" >/dev/null 2>&1 || {
    echo "cluster $CLUSTER is missing; run scripts/07-kubernetes/00-prepare.sh first"
    exit 1
  }
  # Every demo command names its context explicitly, so another cluster cannot be changed accidentally.
  K="kubectl --context $CONTEXT"
}

wait_deployment() { $K -n todo rollout status "deployment/$1" --timeout=180s; }
wait_statefulset() { $K -n todo rollout status "statefulset/$1" --timeout=180s; }

