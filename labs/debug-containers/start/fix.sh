#!/usr/bin/env bash
# Fix each container: remove it and run it again with the right options.
set -u

# 1. sk-db: what does the log say is missing?
docker rm -fv sk-db
# TODO: docker run -d --name sk-db ... postgres:17.12-alpine

# 2. sk-web: which port does nginx listen on INSIDE the container?
docker rm -f sk-web
# TODO: docker run -d --name sk-web -p 8081:<the right port> nginx:1.30.7-alpine

# 3. sk-warmup: exit code 137 and OOMKilled=true. How much memory does it need?
docker rm -f sk-warmup
# TODO: docker run -d --name sk-warmup --memory ... python:3.12.16-alpine3.24 python -c "..."
