#!/usr/bin/env bash
# The fixes for the three broken containers.
set -u

# 1. sk-db: the postgres image refuses to start without a superuser password.
docker rm -fv sk-db
docker run -d --name sk-db --restart on-failure:5 \
  -e POSTGRES_USER=shopkart -e POSTGRES_DB=shopkart -e POSTGRES_PASSWORD=shopkart \
  postgres:17.12-alpine

# 2. sk-web: nginx listens on port 80 inside the container, not 8080.
docker rm -f sk-web
docker run -d --name sk-web -p 8081:80 nginx:1.30.7-alpine

# 3. sk-warmup: the job needs ~150 MB; the limit was 64 MB, so the kernel killed it (exit 137).
docker rm -f sk-warmup
docker run -d --name sk-warmup --memory 256m --memory-swap 256m \
  python:3.12.16-alpine3.24 \
  python -c "print('Loading 150 MB of cart data...', flush=True); data = bytearray(150 * 1024 * 1024); print('Warm-up done')"
