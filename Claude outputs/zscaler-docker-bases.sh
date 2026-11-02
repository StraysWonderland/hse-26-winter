#!/usr/bin/env bash
# PERSONAL helper for a laptop behind Zscaler -- deliberately NOT part of the lecture repo.
#
# Bakes the Zscaler root CA into local copies of the build base images and keeps the original tags.
# `docker build` / `docker compose build` use a local image if one exists, so the repo's Dockerfiles
# need no proxy code at all.
#
# Re-run after `docker pull gradle:9.4-jdk21` or `docker pull node:24-alpine` (a pull replaces the patched tag).
# Prerequisite: the Docker daemon itself trusts the CA (image pulls). Colima, once:
#   security find-certificate -c "Zscaler Root CA" -p /Library/Keychains/System.keychain \
#     | colima ssh -- sudo tee /usr/local/share/ca-certificates/zscaler.crt >/dev/null \
#     && colima ssh -- sudo update-ca-certificates && colima restart
set -euo pipefail
NAME=${CA_NAME:-Zscaler Root CA}
JDK_IMAGES=(gradle:9.4-jdk21)
NODE_IMAGES=(node:24-alpine)

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
security find-certificate -c "$NAME" -p /Library/Keychains/System.keychain >"$TMP/ca.pem" 2>/dev/null \
  || security find-certificate -c "$NAME" -p >"$TMP/ca.pem" \
  || { echo "certificate '$NAME' not found in keychain"; exit 1; }
openssl x509 -in "$TMP/ca.pem" -noout -subject

for img in "${JDK_IMAGES[@]}"; do
  docker pull -q "$img"                     # start from the original, makes re-runs safe
  docker build -q -t "$img" -f - "$TMP" <<EOF
FROM $img
COPY ca.pem /usr/local/share/ca-certificates/corp-ca.crt
RUN keytool -importcert -noprompt -cacerts -storepass changeit -alias corp-ca \
      -file /usr/local/share/ca-certificates/corp-ca.crt
EOF
  echo "patched $img"
done

for img in "${NODE_IMAGES[@]}"; do
  docker pull -q "$img"
  docker build -q -t "$img" -f - "$TMP" <<EOF
FROM $img
COPY ca.pem /usr/local/share/ca-certificates/corp-ca.crt
ENV NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/corp-ca.crt
EOF
  echo "patched $img"
done
