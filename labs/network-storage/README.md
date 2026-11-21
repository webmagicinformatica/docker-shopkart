# Lab: Connect the API to PostgreSQL by name, keep the data

Put the ShopKart API and PostgreSQL on one network so the API reaches the database by its **name**, then prove the data survives when the database container is deleted.

Commands: `start/commands.sh` (TODOs) and `done/commands.sh`. You need `shopkart-api:1.1` from the Dockerfile lab.

## A. The default bridge has no names

```bash
docker run -d --name lonely-db -e POSTGRES_PASSWORD=shopkart postgres:17.12-alpine
docker run --rm python:3.12.16-alpine3.24 ping -c 1 lonely-db       # ping: bad address 'lonely-db'
docker rm -fv lonely-db
```

Containers on the default `bridge` network only know each other's IP addresses.

## B. A user-defined network, a volume and a seed file

```bash
docker network create shopkart
docker volume create shopkart-db
docker run -d --name db --network shopkart \
  -e POSTGRES_USER=shopkart -e POSTGRES_PASSWORD=shopkart -e POSTGRES_DB=shopkart \
  -v shopkart-db:/var/lib/postgresql/data \
  -v "$PWD/app/api/seed.sql:/docker-entrypoint-initdb.d/seed.sql:ro" \
  postgres:17.12-alpine
docker run --rm --network shopkart python:3.12.16-alpine3.24 ping -c 1 db
docker network inspect shopkart --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}'
```

- **Volume** `shopkart-db`: Docker-managed storage for the database files.
- **Bind mount** `seed.sql`: a file from your repo, read-only. Postgres runs it once, on first start with an empty volume.
- On a user-defined network, Docker's built-in DNS answers `db`.

## C. The API uses the database by name

```bash
docker run -d --name api --network shopkart -p 8000:8000 \
  -e DATABASE_URL=postgresql://shopkart:shopkart@db:5432/shopkart \
  shopkart-api:1.1
curl -s localhost:8000/api/info; echo                     # "db":"postgres"
curl -s localhost:8000/api/products | head -c 120; echo
```

## D. The writable layer forgets

```bash
docker exec api sh -c 'echo "remember me" > /tmp/note.txt && cat /tmp/note.txt'
docker rm -f api
docker run -d --name api --network shopkart -p 8000:8000 \
  -e DATABASE_URL=postgresql://shopkart:shopkart@db:5432/shopkart shopkart-api:1.1
docker exec api cat /tmp/note.txt                         # No such file or directory
```

Each container gets its own thin writable layer on top of the image. Delete the container, and the layer goes with it.

## E. A volume remembers

```bash
docker exec db psql -U shopkart -c "INSERT INTO products VALUES (9, 'Cricket Bat', 'Sports', 1999, 15);"
docker rm -f db
curl -s localhost:8000/api/products/9; echo               # 503: the database is gone for now
docker run -d --name db --network shopkart \
  -e POSTGRES_USER=shopkart -e POSTGRES_PASSWORD=shopkart -e POSTGRES_DB=shopkart \
  -v shopkart-db:/var/lib/postgresql/data \
  postgres:17.12-alpine
curl -s localhost:8000/api/products/9; echo               # the Cricket Bat is still there
docker volume inspect shopkart-db --format '{{.Name}} {{.Driver}} {{.Mountpoint}}'
```

The API didn't restart: the new `db` container took the same name, so the API found it again.

## F. tmpfs

```bash
docker run --rm --tmpfs /scratch:size=16m python:3.12.16-alpine3.24 df -h /scratch
```

Memory only: fast, never written to disk, gone when the container stops. Good for scratch files and things that must not persist.

## Clean up

```bash
docker rm -f api db
docker volume rm shopkart-db
docker network rm shopkart
```

## Checkpoint

- [ ] `ping db` fails on the default bridge and works on `shopkart`
- [ ] `/api/info` says `"db":"postgres"`
- [ ] Product 9 survived deleting the database container
