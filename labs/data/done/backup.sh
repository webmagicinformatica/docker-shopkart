#!/usr/bin/env bash
# Two kinds of backup of the ShopKart database. Run from the repo root.
set -euo pipefail
mkdir -p backups
C="docker compose -f labs/data/done/compose.yaml"

# 1. Logical: SQL from pg_dump, while the database runs. Portable across versions and hosts.
$C exec -T db pg_dump -U shopkart -d shopkart --clean --if-exists > backups/shopkart.sql

# 2. Physical: the raw volume as a tarball. Stop the database first so the files are consistent.
$C stop db
docker run --rm -v shopkart-data_db-data:/data:ro -v "$PWD/backups:/backup" alpine:3.24.4 \
  tar czf /backup/db-volume.tar.gz -C /data .
$C start db

ls -lh backups/
