# Connect the API to PostgreSQL by name, keep the data: tested run

Recorded on 2026-11-21 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings and sizes will differ.

Starts from the `shopkart-api:1.1` image (Dockerfile lab). The postgres and python images were already pulled in an earlier lab.

## A. The default bridge has no names

```console
$ docker run -d --name lonely-db -e POSTGRES_PASSWORD=shopkart postgres:17.12-alpine
7a559975f1a818061c7f292bf14491bf19bd0242b488276e3887631e2e1cae8e
$ docker run --rm python:3.12.16-alpine3.24 ping -c 1 lonely-db
ping: bad address 'lonely-db'
$ docker rm -fv lonely-db
lonely-db
```

## B. A user-defined network

```console
$ docker network create shopkart
bdaef241cd8c7eb60b3445952f3695bb53d6ae3c4d4ab89ae61d8099cb77e350
$ docker volume create shopkart-db
shopkart-db
$ docker run -d --name db --network shopkart \
  -e POSTGRES_USER=shopkart -e POSTGRES_PASSWORD=shopkart -e POSTGRES_DB=shopkart \
  -v shopkart-db:/var/lib/postgresql/data \
  -v "$PWD/app/api/seed.sql:/docker-entrypoint-initdb.d/seed.sql:ro" \
  postgres:17.12-alpine
791236aedbffb65d00447cf14de36c62478e9542b8bdd273b16edf29e9fc1865
$ docker run --rm --network shopkart python:3.12.16-alpine3.24 ping -c 1 db
PING db (172.19.0.2): 56 data bytes
64 bytes from 172.19.0.2: seq=0 ttl=64 time=0.133 ms

--- db ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 0.133/0.133/0.133 ms
$ docker network inspect shopkart --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}'
db 172.19.0.2/16

```

## C. The API uses the database by name

```console
$ docker run -d --name api --network shopkart -p 8000:8000 \
  -e DATABASE_URL=postgresql://shopkart:shopkart@db:5432/shopkart \
  shopkart-api:1.1
58e3f2d941b4bd2340c2f5f5fe2b9c79212f50a5eb7a6d274338310e99f315fc
$ curl -s localhost:8000/api/info; echo
{"app":"shopkart-api","version":"1.1","env":"local","db":"postgres","banner":"","host":"58e3f2d941b4"}
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
4212161c9b31486075ad5668546d31b5d5772c58825222064127bf02dd9fb7c9
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
{"detail":"A backing service is unavailable"}
$ docker run -d --name db --network shopkart \
  -e POSTGRES_USER=shopkart -e POSTGRES_PASSWORD=shopkart -e POSTGRES_DB=shopkart \
  -v shopkart-db:/var/lib/postgresql/data \
  postgres:17.12-alpine
67072b215f79de5040498047889509719e6e539ade65d7b1ef5c75d27488befe
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

