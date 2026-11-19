#!/usr/bin/env bash
# Showcase 1 — the smallest Kubernetes workload, and why bare Pods are not enough.
source "$(dirname "$0")/lib.sh"
require_cluster
$K apply -f "$K8S/namespace.yaml" >/dev/null
$K -n todo delete pod frontend-pod --ignore-not-found >/dev/null

step "Run one container as one Pod"
run "$K -n todo run frontend-pod --image=todo-system/frontend:0.1.0 --image-pull-policy=IfNotPresent --port=8080 --env=NGINX_RESOLVER=10.96.0.10"
run "$K -n todo wait --for=condition=Ready pod/frontend-pod --timeout=60s"
run "$K -n todo get pod frontend-pod -o wide"
note "Kubernetes scheduled the Pod and the kubelet started its container"

step "Inspect desired state and runtime events"
run "$K -n todo describe pod frontend-pod"
run "$K -n todo logs frontend-pod --tail=10"

step "A bare Pod has no controller"
run "$K -n todo delete pod frontend-pod"
run "$K -n todo get pods"
note "it stays deleted — next we give the desired replica count to a Deployment"

