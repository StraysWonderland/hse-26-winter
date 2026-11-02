#!/usr/bin/env bash
# Showcase 2 — Run the system container by container; connect containers with a network.
source "$(dirname "$0")/lib.sh"
manual_reset

step "A database without installing one"
run "docker run -d --name postgres -e POSTGRES_USER=todo -e POSTGRES_PASSWORD=todo -e POSTGRES_DB=todo -p 5432:5432 postgres:17-alpine"
wait_pg
run "docker ps"
run "docker exec postgres psql -U todo -c 'select version()'"
note "configuration via environment variables; -p 5432:5432 publishes the port on the host"

step "Our service. Its default database URL is localhost:5432"
run "docker run -d --name todo-service -p 8081:8080 todo-service:1.0"
wait_exit todo-service
run "docker ps -a --filter name=todo-service --format 'table {{.Names}}\t{{.Status}}'"
run_fail "docker logs todo-service 2>&1 | grep -i 'refused'"
note "inside a container, localhost is the container itself. -p only maps host -> container."
run "docker rm todo-service"

step "User-defined network: containers reach each other by name"
run "docker network create todo-net"
run "docker network connect todo-net postgres"
run "docker run -d --name todo-service --network todo-net -p 8081:8080 -e DB_URL=jdbc:postgresql://postgres:5432/todo todo-service:1.0"
wait_http localhost:8081/actuator/health/readiness
run "curl -s -X POST localhost:8081/api/todos -H 'Content-Type: application/json' -d '{\"title\":\"Hello from curl\"}' | jq ."
run "curl -s localhost:8081/api/todos | jq ."

step "Frontend on the same network, only its port is published"
run "docker run -d --name frontend --network todo-net -p 8080:8080 todo-frontend:1.0"
wait_http localhost:8080/healthz
note "open http://localhost:8080 — activity panel: not reachable, not started yet (showcase 5)"
run "docker network inspect todo-net --format '{{range .Containers}}{{.Name}}  {{.IPv4Address}}{{println}}{{end}}'"
