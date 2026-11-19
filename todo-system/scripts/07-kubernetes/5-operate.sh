#!/usr/bin/env bash
# Showcase 5 — scale, self-heal, inspect, roll out and roll back an application.
source "$(dirname "$0")/lib.sh"
require_cluster
$K -n todo get deployment todo-service >/dev/null 2>&1 || { echo "run 4-full-system.sh first"; exit 1; }

step "Scale a stateless service"
run "$K -n todo scale deployment todo-service --replicas=3"
wait_deployment todo-service
run "$K -n todo get pods -l app.kubernetes.io/name=todo-service -o wide"
run "for i in 1 2 3 4 5 6; do curl -fs -o /dev/null -D - localhost:8080/api/todos | grep -i x-served-by; done"
note "the Service balances requests across ready replicas"

step "Self-healing: remove a replica behind the Service"
POD=$($K -n todo get pod -l app.kubernetes.io/name=todo-service -o jsonpath='{.items[0].metadata.name}')
run "$K -n todo delete pod $POD"
wait_deployment todo-service
run "$K -n todo get pods -l app.kubernetes.io/name=todo-service"
run "curl -fs localhost:8080/api/todos"

step "Rolling update to version 0.2.0"
PATCH='{"spec":{"template":{"spec":{"containers":[{"name":"todo-service","image":"todo-system/todo-service:0.2.0","env":[{"name":"APP_VERSION","value":"0.2.0"}]}]}}}}'
run "$K -n todo patch deployment todo-service --type=strategic -p '$PATCH'"
run "$K -n todo rollout status deployment/todo-service --timeout=180s"
run "$K -n todo rollout history deployment/todo-service"
run "curl -fs -o /dev/null -D - localhost:8080/api/todos | grep -Ei 'x-app-version|x-served-by'"
note "maxUnavailable: 0 keeps old replicas ready while new ones start"

step "Undo the release"
run "$K -n todo rollout undo deployment/todo-service"
run "$K -n todo rollout status deployment/todo-service --timeout=180s"
run "curl -fs -o /dev/null -D - localhost:8080/api/todos | grep -Ei 'x-app-version|x-served-by'"

step "The first commands during an incident"
run "$K -n todo get events --sort-by=.lastTimestamp | tail -n 15"
run "$K -n todo logs deployment/todo-service --tail=10 --prefix"
note "describe explains state and events; logs shows application output; rollout history shows releases"

