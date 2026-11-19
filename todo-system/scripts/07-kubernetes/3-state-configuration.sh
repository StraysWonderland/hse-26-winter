#!/usr/bin/env bash
# Showcase 3 — configuration, secrets, probes and persistent state.
source "$(dirname "$0")/lib.sh"
require_cluster
$K apply -f "$K8S/namespace.yaml" >/dev/null

step "ConfigMap and Secret keep configuration outside images"
run "cat $POSTGRES_K8S/configmap.yaml $POSTGRES_K8S/secret.yaml"
run "$K apply -k $POSTGRES_K8S"
run "$K apply -k $NATS_K8S"
run "$K -n todo get configmap,secret"
note "Secret values are not printed here, but base64 is not encryption; use RBAC and encryption at rest in production"

step "A StatefulSet gives Postgres stable identity and persistent storage"
wait_statefulset postgres
wait_deployment nats
run "$K -n todo get statefulset,pod,service,pvc"
run "$K -n todo describe pvc data-postgres-0"
note "the claim is independent of the Pod and is bound to storage supplied by the cluster"

step "Probes decide whether a container is alive and ready for traffic"
run "$K -n todo describe pod postgres-0 | sed -n '/Containers:/,/Conditions:/p'"

step "Replace the database Pod, keep its volume"
run "$K -n todo delete pod postgres-0"
wait_statefulset postgres
run "$K -n todo get pod postgres-0 -o wide"
run "$K -n todo get pvc data-postgres-0"
note "same StatefulSet identity and PVC, new Pod instance"

