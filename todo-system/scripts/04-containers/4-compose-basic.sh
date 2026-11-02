#!/usr/bin/env bash
# Showcase 4 — Showcases 2 and 3 as one file.
source "$(dirname "$0")/lib.sh"
manual_reset
docker volume rm pgdata >/dev/null 2>&1 || true
cd "$DEMO"

step "Everything we typed, written down"
run "cat compose.yaml"

step "One command for the whole system"
run "docker compose up -d"
wait_http localhost:8080/healthz
run "docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'"
run "docker network ls --filter name=todo-basic; docker volume ls --filter name=todo-basic"
note "network and volume created automatically, names prefixed with the project name"
wait_http localhost:8080/api/todos
run "curl -s -X POST localhost:8080/api/todos -H 'Content-Type: application/json' -d '{\"title\":\"Hello Compose\"}' | jq -r .title"

step "Logs of all services"
run "docker compose logs --tail 3"

step "down keeps volumes, down -v removes them"
run "docker compose down && docker compose up -d"
wait_http localhost:8080/api/todos
run "curl -s localhost:8080/api/todos | jq -r '.[].title'"
run "docker compose down -v"
