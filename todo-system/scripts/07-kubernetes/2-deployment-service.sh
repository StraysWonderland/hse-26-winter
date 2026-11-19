#!/usr/bin/env bash
# Showcase 2 — declarative desired state, a Deployment controller and stable Service discovery.
source "$(dirname "$0")/lib.sh"
require_cluster
$K apply -f "$K8S/namespace.yaml" >/dev/null

step "Declare two frontend replicas and one stable network endpoint"
run "cat $FRONTEND_K8S/deployment.yaml $FRONTEND_K8S/service.yaml"
run "$K apply -k $FRONTEND_K8S"
wait_deployment frontend
run "$K -n todo get deployment,replicaset,pod -l app.kubernetes.io/name=frontend"

step "A Service selects changing Pods by label"
run "$K -n todo get service frontend"
run "$K -n todo get endpointslice -l kubernetes.io/service-name=frontend"
run "curl -fs http://localhost:8080/healthz"
note "kind maps the NodePort 30080 to localhost:8080"

step "The Deployment reconciles actual state back to desired state"
POD=$($K -n todo get pod -l app.kubernetes.io/name=frontend -o jsonpath='{.items[0].metadata.name}')
run "$K -n todo delete pod $POD"
wait_deployment frontend
run "$K -n todo get pods -l app.kubernetes.io/name=frontend"
note "a replacement Pod appeared automatically; its name and IP are disposable"

