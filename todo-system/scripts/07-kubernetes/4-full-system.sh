#!/usr/bin/env bash
# Showcase 4 — deploy the complete system from declarative manifests.
source "$(dirname "$0")/lib.sh"
require_cluster

step "Kustomize groups the system's manifests without copying YAML"
run "cat $ROOT/kustomization.yaml"
run "$K apply -k $ROOT"

step "Wait until every workload is available"
wait_statefulset postgres
for deployment in nats todo-service activity-service frontend; do wait_deployment "$deployment"; done
run "$K -n todo get all"
run "$K -n todo get pvc"

step "Use the application through the frontend Service"
run "curl -fs -X POST localhost:8080/api/todos -H 'Content-Type: application/json' -d '{\"title\":\"Hello Kubernetes\"}'"
run "curl -fs localhost:8080/api/todos"
note "open http://localhost:8080 — the TODO and activity panels should both work"

step "Services provide DNS names; Pods remain replaceable"
run "$K -n todo exec deploy/frontend -- getent hosts todo-service"
run "$K -n todo get endpointslice -l kubernetes.io/service-name=todo-service"
note "frontend calls todo-service:8080; the Service routes to whichever ready Pods match its selector"

