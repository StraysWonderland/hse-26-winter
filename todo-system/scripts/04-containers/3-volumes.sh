#!/usr/bin/env bash
# Showcase 3 — Where does the data live? Container layer vs named volume. Needs showcase 2 running.
source "$(dirname "$0")/lib.sh"
docker inspect frontend >/dev/null 2>&1 || { echo "run 2-run-network.sh first"; exit 1; }
PG="--name postgres --network todo-net -e POSTGRES_USER=todo -e POSTGRES_PASSWORD=todo -e POSTGRES_DB=todo"
add() { curl -s -X POST localhost:8080/api/todos -H 'Content-Type: application/json' -d "{\"title\":\"$1\"}" >/dev/null; }
docker volume rm pgdata >/dev/null 2>&1 || true

step "Stop and start: data survives (the container still exists)"
add "survives a restart"
run "curl -s localhost:8080/api/todos | jq -r '.[].title'"
run "docker stop postgres && docker start postgres"
wait_pg
run "curl -s localhost:8080/api/todos | jq -r '.[].title'"

step "Remove and recreate: data is gone, it lived in the container's writable layer"
run "docker rm -f postgres"
run "docker run -d $PG postgres:17-alpine"
wait_pg
run_fail "curl -sf localhost:8080/api/todos"
note "even the table is gone. todo-service creates its schema at startup -> restart it"
run "docker restart todo-service"
wait_http localhost:8081/actuator/health/readiness
run "curl -s localhost:8080/api/todos | jq ."

step "Named volume: data lives outside the container"
run "docker rm -f postgres"
run "docker run -d $PG -v pgdata:/var/lib/postgresql/data postgres:17-alpine"
wait_pg
run "docker restart todo-service"
wait_http localhost:8081/actuator/health/readiness
add "stored in a volume"
run "curl -s localhost:8080/api/todos | jq -r '.[].title'"
run "docker rm -f postgres"
run "docker run -d $PG -v pgdata:/var/lib/postgresql/data postgres:17-alpine"
wait_pg
run "curl -s localhost:8080/api/todos | jq -r '.[].title'"
note "new container, same data. No todo-service restart needed: the schema survived too"
run "docker volume ls"
run "docker volume inspect pgdata --format '{{.Mountpoint}}'"
note "managed by Docker (inside the VM on macOS). Bind mount instead: -v ./host/path:/container/path"
