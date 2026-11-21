#!/usr/bin/env bash
# Two kinds of backup of the ShopKart database. Fill in the TODOs. Run from the repo root.
set -euo pipefail
mkdir -p backups
C="docker compose -f labs/data/start/compose.yaml"

# 1. Logical: TODO run pg_dump inside the db service (exec -T), into backups/shopkart.sql
#    pg_dump -U shopkart -d shopkart --clean --if-exists

# 2. Physical: TODO stop db, tar the volume shopkart-data_db-data with a throwaway alpine:3.24.4
#    container into backups/db-volume.tar.gz, then start db again

ls -lh backups/
