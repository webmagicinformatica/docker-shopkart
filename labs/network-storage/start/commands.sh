#!/usr/bin/env bash
# Networking and storage. Fill in the TODOs, then run the blocks one at a time.
# Run the blocks one at a time from the repo root. Needs shopkart-api:1.1 (Dockerfile lab).

# --- A. The default bridge has no names ---
docker run -d --name lonely-db -e POSTGRES_PASSWORD=shopkart postgres:17.12-alpine
docker run --rm python:3.12.16-alpine3.24 ping -c 1 lonely-db
docker rm -fv lonely-db

# --- B. A user-defined network: containers find each other by name ---
# TODO: create a network called shopkart
docker volume create shopkart-db
# TODO: run postgres:17.12-alpine named db on the shopkart network, user/password/db = shopkart,
#       volume shopkart-db at /var/lib/postgresql/data, and app/api/seed.sql bind-mounted (read-only)
#       into /docker-entrypoint-initdb.d/
docker run --rm --network shopkart python:3.12.16-alpine3.24 ping -c 1 db

# --- C. The API uses the database by its name: db ---
# TODO: run shopkart-api:1.1 named api on the shopkart network, port 8000,
#       with DATABASE_URL=postgresql://shopkart:shopkart@<the db's name>:5432/shopkart
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
# TODO: run db again with the SAME volume (the seed mount isn't needed any more)
sleep 4
curl -s localhost:8000/api/products/9; echo
docker volume inspect shopkart-db --format '{{.Name}} {{.Driver}} {{.Mountpoint}}'

# --- F. tmpfs: in memory only, gone when the container stops ---
docker run --rm --tmpfs /scratch:size=16m python:3.12.16-alpine3.24 df -h /scratch

# --- Clean up ---
docker rm -f api db
docker volume rm shopkart-db
docker network rm shopkart
