#!/usr/bin/env bash
# Maintainer step, run once per dependency change -- NOT needed by students once the output is committed.
# Generates the Gradle wrappers and the npm lockfile inside containers (no local JDK/Gradle/Node needed).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GRADLE_IMAGE=gradle:9.4-jdk21     # keep in sync with the Dockerfiles
NODE_IMAGE=node:24-alpine
USR="$(id -u):$(id -g)"

# Wrapper only: generated in an empty directory, so Gradle does not evaluate build.gradle.kts
# (no plugin resolution, no network). Version = the Gradle version of $GRADLE_IMAGE.
for svc in todo-service activity-service; do
  echo ">> gradle wrapper: $svc"
  docker run --rm -u "$USR" -e GRADLE_USER_HOME=/tmp/gradle -v "$ROOT/services/$svc:/out" "$GRADLE_IMAGE" \
    sh -c 'set -e; mkdir /tmp/w && cd /tmp/w && touch settings.gradle.kts
           gradle wrapper --no-daemon -q
           cp -r gradlew gradlew.bat gradle /out/'
done

echo ">> npm lockfile: frontend"
docker run --rm -u "$USR" -e npm_config_cache=/tmp/npm -v "$ROOT/services/frontend:/w" -w /w "$NODE_IMAGE" \
  npm install --no-audit --no-fund --package-lock-only

echo "Done. Commit services/*/gradlew*, services/*/gradle/, services/frontend/package-lock.json"
