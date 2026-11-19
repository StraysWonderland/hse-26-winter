#!/usr/bin/env bash
# Run before the lecture: create the local cluster, build images and load them into kind.
source "$(dirname "$0")/lib.sh"

for tool in docker kind kubectl curl; do
  command -v "$tool" >/dev/null || { echo "missing: $tool"; exit 1; }
done
docker info >/dev/null

if ! kind get clusters | grep -qx "$CLUSTER"; then
  step "Create an isolated, local Kubernetes cluster"
  run "kind create cluster --name $CLUSTER --config $K8S/local/kind-config.yaml"
else
  note "kind cluster $CLUSTER already exists; keeping it"
fi

step "Build the same application images used by the Docker lecture"
run "docker build -q --build-arg APP_VERSION=0.1.0 -t todo-system/todo-service:0.1.0 services/todo-service"
run "docker build -q --build-arg APP_VERSION=0.2.0 -t todo-system/todo-service:0.2.0 services/todo-service"
run "docker build -q --build-arg APP_VERSION=0.1.0 -t todo-system/activity-service:0.1.0 services/activity-service"
run "docker build -q --build-arg APP_VERSION=0.1.0 -t todo-system/frontend:0.1.0 services/frontend"

step "Load local images into the cluster's container runtime"
IMAGES=(
  todo-system/todo-service:0.1.0
  todo-system/todo-service:0.2.0
  todo-system/activity-service:0.1.0
  todo-system/frontend:0.1.0
  postgres:17-alpine
)
for image in "${IMAGES[@]}"; do
  run "kind load docker-image --name $CLUSTER $image"
done

step "Check the cluster"
run "kubectl --context $CONTEXT wait --for=condition=Ready node --all --timeout=120s"
run "kubectl --context $CONTEXT cluster-info"
run "kubectl --context $CONTEXT get nodes -o wide"
note "ready — continue with scripts/07-kubernetes/1-pod.sh"

