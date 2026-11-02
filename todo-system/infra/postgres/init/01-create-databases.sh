#!/bin/sh
# Runs once, on first start with an empty data volume.
# One Postgres instance, one database + owner per service (database-per-service, shared server).
set -eu
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
  CREATE USER todo WITH PASSWORD '${TODO_DB_PASSWORD}';
  CREATE DATABASE todo OWNER todo;
  CREATE USER activity WITH PASSWORD '${ACTIVITY_DB_PASSWORD}';
  CREATE DATABASE activity OWNER activity;
EOSQL
