#!/usr/bin/env bash
# Helpers for live demos: each command is shown, then runs after Enter. AUTO=1 runs without pauses.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
DEMO=$ROOT/scripts/04-containers
ALPINE=alpine:3.22
cd "$ROOT"
[[ -f .env ]] && { set -a; source .env; set +a; }

if [[ -t 1 ]]; then B=$'\e[1m'; C=$'\e[36m'; Y=$'\e[33m'; N=$'\e[0m'; else B= C= Y= N=; fi

step() { printf '\n%s## %s%s\n' "$C" "$*" "$N"; }
note() { printf '%s> %s%s\n' "$Y" "$*" "$N"; }
pause() { [[ "${AUTO:-0}" == 1 ]] && { echo; return; }; read -r _ </dev/tty; }
run() { printf '%s$ %s%s' "$B" "$*" "$N"; pause; eval "$@"; }
# For commands that are expected to fail as part of the point being made.
run_fail() { printf '%s$ %s%s' "$B" "$*" "$N"; pause; eval "$@" || printf '%s(exit %s — expected)%s\n' "$Y" "$?" "$N"; }

is_desktop() { [[ "$(docker info --format '{{.OperatingSystem}}' 2>/dev/null)" == *"Docker Desktop"* ]]; }
# Daemon runs in a VM (Docker Desktop, Colima, Rancher Desktop, ...) instead of on this host.
is_vm() { [[ "$(uname -s)" != Linux ]] || is_desktop; }

# Run a command in the namespaces of the machine that runs dockerd (host or VM).
host_sh() {
  if is_vm; then
    docker run --rm --privileged --pid=host "$ALPINE" nsenter -t 1 -m -u -n -i sh -c "$1"
  else
    sudo sh -c "$1"
  fi
}

rm_ctr() { docker rm -f "$@" >/dev/null 2>&1 || true; }

# Wait until a URL answers 2xx (max ~90 s).
wait_http() { for _ in $(seq 90); do curl -fs -o /dev/null "$1" && return 0; sleep 1; done; echo "timeout: $1"; return 1; }
# Wait until a container has stopped (max ~60 s).
wait_exit() { for _ in $(seq 60); do [[ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" == false ]] && return 0; sleep 1; done; }
# Wait until the postgres container accepts TCP connections (not just the init-phase socket).
wait_pg() { for _ in $(seq 60); do docker exec postgres pg_isready -q -h 127.0.0.1 2>/dev/null && return 0; sleep 1; done; }
# Showcase 2/3 containers and network.
manual_reset() { rm_ctr frontend todo-service postgres; docker network rm todo-net >/dev/null 2>&1 || true; }
