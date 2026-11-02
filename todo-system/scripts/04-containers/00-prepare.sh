#!/usr/bin/env bash
# Before the lecture (on reliable network): checks tools, pulls and builds everything once.
# Afterwards all showcases run from local cache; only showcase 1's naive rebuild needs network.
source "$(dirname "$0")/lib.sh"
for t in docker curl jq; do command -v "$t" >/dev/null || { echo "missing: $t"; exit 1; }; done
docker compose version >/dev/null || { echo "missing compose plugin (see README)"; exit 1; }
docker buildx version >/dev/null || { echo "missing buildx plugin (see README)"; exit 1; }
MEM_GB=$(( $(docker info --format '{{.MemTotal}}') / 1024 / 1024 / 1024 ))
(( MEM_GB >= 6 )) || echo "WARNING: Docker VM has ${MEM_GB} GiB RAM, ~6 GiB recommended (colima start --cpu 4 --memory 8)"
[[ -f services/frontend/package-lock.json ]] || { echo "package-lock.json missing: run scripts/bootstrap.sh and commit"; exit 1; }

# Build base images (gradle, node) are pulled by the builds below if missing.
for img in postgres:17-alpine nats:2.11-alpine natsio/nats-box:latest eclipse-temurin:21-jre-alpine \
           nginxinc/nginx-unprivileged:1.28-alpine "$ALPINE"; do
  docker pull -q "$img"
done
docker build -q -f scripts/04-containers/Dockerfile.naive -t todo-service:naive services/todo-service
docker build -q -t todo-service:1.0 services/todo-service
docker build -q -t todo-frontend:1.0 services/frontend
docker compose build -q
KEEP_IMAGES=1 "$DEMO/99-reset.sh" >/dev/null
echo "ready"
