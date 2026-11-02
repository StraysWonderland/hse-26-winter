#!/usr/bin/env bash
# Showcase 5 — The full system: separate networks, health checks, init script, events, limits, scaling.
source "$(dirname "$0")/lib.sh"
manual_reset
(cd "$DEMO" && docker compose down -v >/dev/null 2>&1) || true

step "The production-like compose file"
run "cat compose.yaml"
note "two networks, health checks + depends_on conditions, init-script bind mount, limits"

step "Start, wait until all health checks are green"
run "docker compose up -d --wait"
run "docker compose ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'"
note "UI: http://localhost:8080   NATS monitoring: http://localhost:8222"

step "Events: watch NATS live while using the UI"
note "second terminal: docker run --rm -it --network todo-system_backend natsio/nats-box nats sub -s nats://nats:4222 'todo.>'"
run "curl -s -X POST localhost:8080/api/todos -H 'Content-Type: application/json' -d '{\"title\":\"Prepare demo\"}' | jq -r .title"
sleep 1
run "curl -s localhost:8080/api/activity | jq '.[0] | {type, title, receivedBy}'"

step "Network segmentation: the frontend cannot even resolve the database"
run_fail "docker compose exec frontend nslookup postgres"
run "docker compose exec todo-service nslookup postgres | tail -n 2"

step "Scale the stateless service"
run "docker compose up -d --wait --scale todo-service=3"
run "for i in 1 2 3 4 5 6; do curl -s -o /dev/null -D - localhost:8080/api/todos | grep -i x-served-by; done"
note "watch the 'Who answered' strip in the UI. Postgres cannot be scaled like this: state."

step "Limits from compose.yaml are enforced by the kernel (cgroups)"
run "docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'"

step "What Compose does not do"
run "docker kill \$(docker compose ps -q todo-service | head -n 1)"
run "docker compose ps -a todo-service --format 'table {{.Name}}\t{{.Status}}'"
note "one machine, nobody replaces the killed replica -> Kubernetes"
