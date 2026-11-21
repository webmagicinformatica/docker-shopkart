# Connect the API to PostgreSQL by name, keep the data: tested run

Recorded on 2026-11-21 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings and sizes will differ.

Starts from the `shopkart-api:1.1` image (Dockerfile lab). The postgres and python images were already pulled in an earlier lab.

## A. The default bridge has no names

```console
$ docker run -d --name lonely-db -e POSTGRES_PASSWORD=shopkart postgres:17.12-alpine
28da22af970dad090fe1b3b848551181ab6c41b587a08da4bdd0e827e8307bc8
$ docker run --rm python:3.12.16-alpine3.24 ping -c 1 lonely-db
ping: bad address 'lonely-db'
$ docker rm -fv lonely-db
lonely-db
```

## B. A user-defined network

```console
$ docker network create shopkart
7d4052293664ce53551bc55033e533dae929398bfdd3ee289566a2ed20fae975
$ docker volume create shopkart-db
shopkart-db
$ docker run -d --name db --network shopkart \
  -e POSTGRES_USER=shopkart -e POSTGRES_PASSWORD=shopkart -e POSTGRES_DB=shopkart \
  -v shopkart-db:/var/lib/postgresql/data \
  -v "$PWD/app/api/seed.sql:/docker-entrypoint-initdb.d/seed.sql:ro" \
  postgres:17.12-alpine
d2ac9e357c9a86e7c3d379349d3428c0e2b51e3889c55073c0b28a003c0df7ed
$ docker run --rm --network shopkart python:3.12.16-alpine3.24 ping -c 1 db
PING db (172.19.0.2): 56 data bytes
64 bytes from 172.19.0.2: seq=0 ttl=64 time=0.173 ms

--- db ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 0.173/0.173/0.173 ms
$ docker network inspect shopkart --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}'
db 172.19.0.2/16

```

## C. The API uses the database by name

```console
$ docker run -d --name api --network shopkart -p 8000:8000 \
  -e DATABASE_URL=postgresql://shopkart:shopkart@db:5432/shopkart \
  shopkart-api:1.1
81e292f2a70af2ba75b989cf0289ed30377ca4c91a222751ee25107f0baf0359
$ curl -s localhost:8000/api/info; echo
{"app":"shopkart-api","version":"1.1","env":"local","db":"postgres","banner":"","host":"81e292f2a70a"}
$ curl -s localhost:8000/api/products | head -c 120; echo
[{"id":1,"name":"Cotton Kurta","category":"Clothing","price_inr":899,"stock":40},{"id":2,"name":"Running Shoes","categor
```

## D. The writable layer forgets

```console
$ docker exec api sh -c 'echo "remember me" > /tmp/note.txt && cat /tmp/note.txt'
remember me
$ docker rm -f api
api
$ docker run -d --name api --network shopkart -p 8000:8000 \
  -e DATABASE_URL=postgresql://shopkart:shopkart@db:5432/shopkart shopkart-api:1.1
d1481d56bb852c4a7cbce7c37d27e358e70357ee4a32d15649aa4a658bc8239b
$ docker exec api cat /tmp/note.txt
cat: /tmp/note.txt: No such file or directory
```

## E. A volume remembers

```console
$ docker exec db psql -U shopkart -c "INSERT INTO products VALUES (9, 'Cricket Bat', 'Sports', 1999, 15);"
INSERT 0 1
$ docker rm -f db
db
$ curl -s localhost:8000/api/products/9; echo
Internal Server Error
$ docker run -d --name db --network shopkart \
  -e POSTGRES_USER=shopkart -e POSTGRES_PASSWORD=shopkart -e POSTGRES_DB=shopkart \
  -v shopkart-db:/var/lib/postgresql/data \
  postgres:17.12-alpine
74005ef2ca707040fa40e2d69f37b56213f2a2ee408a37b74eae4107de9c00a5
$ curl -s localhost:8000/api/products/9; echo
{"id":9,"name":"Cricket Bat","category":"Sports","price_inr":1999,"stock":15}
$ docker volume inspect shopkart-db --format '{{.Name}} {{.Driver}} {{.Mountpoint}}'
shopkart-db local /var/lib/docker/volumes/shopkart-db/_data
```

## F. tmpfs

```console
$ docker run --rm --tmpfs /scratch:size=16m python:3.12.16-alpine3.24 df -h /scratch
Filesystem                Size      Used Available Use% Mounted on
tmpfs                    16.0M         0     16.0M   0% /scratch
```

## Clean up

```console
$ docker rm -f api db
api
db
$ docker volume rm shopkart-db
shopkart-db
$ docker network rm shopkart
shopkart
```

