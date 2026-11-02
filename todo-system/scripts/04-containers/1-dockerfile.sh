#!/usr/bin/env bash
# Showcase 1 — Dockerfile: naive vs multi-stage. Size, rebuild time after a code change, layers.
source "$(dirname "$0")/lib.sh"
CTX=services/todo-service
STAMP=$CTX/src/main/resources/build-stamp.txt
trap 'rm -f "$STAMP"' EXIT

step "Naive: one stage, build tools and sources end up in the image"
run "cat scripts/04-containers/Dockerfile.naive"
run "docker build -f scripts/04-containers/Dockerfile.naive -t todo-service:naive $CTX"
note "-f = which Dockerfile, last argument = build context (the files COPY can see)"

step "Multi-stage: build in a JDK+Gradle stage, run on a small JRE image"
run "cat $CTX/Dockerfile"
run "docker build -t todo-service:1.0 $CTX"

step "Compare"
run "docker image ls todo-service"
run "docker run --rm --entrypoint id todo-service:naive; docker run --rm --entrypoint id todo-service:1.0"
note "naive runs as root, the multi-stage image as an unprivileged user"

step "Change one file and rebuild both"
run "date > $STAMP"
run "time docker build -q -f scripts/04-containers/Dockerfile.naive -t todo-service:naive $CTX"
run "time docker build -q -t todo-service:1.0 $CTX"
note "naive: COPY . . changed -> every later layer rebuilt, all dependencies downloaded again"
note "multi-stage: dependency cache mount survives; only the application layer is new"

step "An image is a stack of layers"
run "docker history --format 'table {{.Size}}\t{{.CreatedBy}}' todo-service:1.0 | head -n 8"

step "Same pattern for the frontend: Node builds static files, nginx serves them (no Node at runtime)"
run "docker build -q -t todo-frontend:1.0 services/frontend"
run "docker image ls todo-frontend"
