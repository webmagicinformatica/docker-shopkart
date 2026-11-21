#!/usr/bin/env bash
# Networking and storage: the API talks to PostgreSQL by name, and the data survives.
# Run the blocks one at a time from the repo root. Needs shopkart-api:1.1 (Dockerfile lab).

# --- A. The default bridge has no names ---
docker run -d --name lonely-db -e POSTGRES_PASSWORD=shopkart postgres:17.12-alpine
docker run --rm python:3.12.16-alpine3.24 ping -c 1 lonely-db
docker rm -fv lonely-db

# --- B. A user-defined network: containers find each other by name ---
docker network create shopkart
docker volume create shopkart-db
docker run -d --name db --network shopkart \
  -e POSTGRES_USER=shopkart -e POSTGRES_PASSWORD=shopkart -e POSTGRES_DB=shopkart \
  -v shopkart-db:/var/lib/postgresql/data \
  -v "$PWD/app/api/seed.sql:/docker-entrypoint-initdb.d/seed.sql:ro" \
  postgres:17.12-alpine
docker run --rm --network shopkart python:3.12.16-alpine3.24 ping -c 1 db

# --- C. The API uses the database by its name: db ---
docker run -d --name api --network shopkart -p 8000:8000 \
  -e DATABASE_URL=postgresql://shopkart:shopkart@db:5432/shopkart \
  shopkart-api:1.1
sleep 4
curl -s localhost:8000/api/info; echo
curl -s localhost:8000/api/products | head -c 120; echo

# --- D. The writable layer forgets ---
docker exec api sh -c 'echo "remember me" > /tmp/note.txt && cat /tmp/note.txt'
docker rm -f api
docker run -d --name api --network shopkart -p 8000:8000 \
  -e DATABASE_URL=postgresql://shopkart:shopkart@db:5432/shopkart shopkart-api:1.1
docker exec api cat /tmp/note.txt

# --- E. A volume remembers ---
docker exec db psql -U shopkart -c "INSERT INTO products VALUES (9, 'Cricket Bat', 'Sports', 1999, 15);"
docker rm -f db
curl -s localhost:8000/api/products/9; echo      # the database is gone for now
docker run -d --name db --network shopkart \
  -e POSTGRES_USER=shopkart -e POSTGRES_PASSWORD=shopkart -e POSTGRES_DB=shopkart \
  -v shopkart-db:/var/lib/postgresql/data \
  postgres:17.12-alpine
sleep 4
curl -s localhost:8000/api/products/9; echo
docker volume inspect shopkart-db --format '{{.Name}} {{.Driver}} {{.Mountpoint}}'

# --- F. tmpfs: in memory only, gone when the container stops ---
docker run --rm --tmpfs /scratch:size=16m python:3.12.16-alpine3.24 df -h /scratch

# --- Clean up ---
docker rm -f api db
docker volume rm shopkart-db
docker network rm shopkart
