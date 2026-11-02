#!/usr/bin/env bash
# Remove everything the showcases created. KEEP_IMAGES=1 keeps built images.
source "$(dirname "$0")/lib.sh"
manual_reset
docker volume rm pgdata >/dev/null 2>&1 || true
(cd "$DEMO" && docker compose down -v --remove-orphans) >/dev/null 2>&1 || true
docker compose down -v --remove-orphans
if [[ "${KEEP_IMAGES:-0}" != 1 ]]; then
  docker image rm -f todo-service:naive todo-service:1.0 todo-frontend:1.0 >/dev/null 2>&1 || true
fi
echo "clean"
