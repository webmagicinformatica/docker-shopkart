#!/usr/bin/env bash
# Starts three BROKEN ShopKart containers. Don't read the fix in here: debug them with
# docker ps, logs, inspect, exec and stats (see README.md).
set -u

# 1. The database keeps restarting
docker run -d --name sk-db --restart on-failure:5 \
  -e POSTGRES_USER=shopkart -e POSTGRES_DB=shopkart \
  postgres:17.12-alpine

# 2. The web server is "up", but the page never loads
docker run -d --name sk-web -p 8081:8080 nginx:1.30.7-alpine

# 3. The cart warm-up job dies a second after it starts
docker run -d --name sk-warmup --memory 64m --memory-swap 64m \
  python:3.12.16-alpine3.24 \
  python -c "print('Loading 150 MB of cart data...', flush=True); data = bytearray(150 * 1024 * 1024); print('Warm-up done')"

echo "Three containers started. Now find out what's wrong: docker ps -a"
