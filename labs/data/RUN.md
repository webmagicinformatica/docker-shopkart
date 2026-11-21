# Back up, wipe and restore ShopKart; run a migration: tested run

Recorded on 2026-11-21 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings and sizes will differ.

Uses the `shopkart-api:1.2` image from the config lab.

## 1. Start, and add data worth saving

```console
$ docker compose -f labs/data/done/compose.yaml up -d --wait 2>&1 | tail -n 2
 Container shopkart-data-db-1  Healthy
 Container shopkart-data-api-1  Healthy
$ docker compose -f labs/data/done/compose.yaml exec db psql -U shopkart -c "INSERT INTO products VALUES (9, 'Cricket Bat', 'Sports', 1999, 15);"
INSERT 0 1
$ curl -s localhost:8000/api/products | python3 -c 'import json,sys; print(len(json.load(sys.stdin)), "products")'
9 products
```

## 2. Back up two ways

```console
$ ./labs/data/done/backup.sh
 Container shopkart-data-db-1  Stopping
 Container shopkart-data-db-1  Stopped
Unable to find image 'alpine:3.24.4' locally
3.24.4: Pulling from library/alpine
881fc932939e: Pulling fs layer
881fc932939e: Already exists
86ff264fe568: Download complete
c35a7d82b8fa: Download complete
Digest: sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf
Status: Downloaded newer image for alpine:3.24.4
 Container shopkart-data-db-1  Starting
 Container shopkart-data-db-1  Started
total 6.3M
-rw-r--r-- 1 root   root   6.3M Nov 21 20:11 db-volume.tar.gz
-rw-r--r-- 1 vscode vscode 1.8K Nov 21 20:11 shopkart.sql
$ head -n 5 backups/shopkart.sql
--
-- PostgreSQL database dump
--

\restrict clNub2dFWOk4TVc45pitztnywj8fmcpcMvG9p4HxzVgH8tMwUbMZhCCCBVxwKIa
```

## 3. Disaster: wipe everything

```console
$ docker compose -f labs/data/done/compose.yaml down -v 2>&1 | tail -n 3
 Volume shopkart-data_db-data  Removing
 Volume shopkart-data_db-data  Removed
 Network shopkart-data_default  Removed
$ docker volume ls --filter name=shopkart-data
DRIVER    VOLUME NAME
$ docker compose -f labs/data/done/compose.yaml up -d --wait 2>&1 | tail -n 2
 Container shopkart-data-db-1  Healthy
 Container shopkart-data-api-1  Healthy
$ curl -s localhost:8000/api/products | python3 -c 'import json,sys; print(len(json.load(sys.stdin)), "products")'
8 products
```

## 4. Restore from the SQL dump

```console
$ docker compose -f labs/data/done/compose.yaml exec -T db psql -q -U shopkart -d shopkart < backups/shopkart.sql
 set_config 
------------
 
(1 row)

$ curl -s localhost:8000/api/products/9; echo
{"id":9,"name":"Cricket Bat","category":"Sports","price_inr":1999,"stock":15}
```

## 5. Restore the volume tarball

```console
$ docker compose -f labs/data/done/compose.yaml down -v 2>&1 | tail -n 1
 Network shopkart-data_default  Removed
$ docker volume create shopkart-data_db-data
shopkart-data_db-data
$ docker run --rm -v shopkart-data_db-data:/data -v "$PWD/backups:/backup:ro" alpine:3.24.4 tar xzf /backup/db-volume.tar.gz -C /data
$ docker compose -f labs/data/done/compose.yaml up -d --wait 2>&1 | grep -v -E 'Waiting|Starting|Created|Creating'
time="2026-11-21T20:11:33Z" level=warning msg="volume \"shopkart-data_db-data\" already exists but was not created by Docker Compose. Use `external: true` to use an existing volume"
 Container shopkart-data-db-1  Started
 Container shopkart-data-db-1  Healthy
 Container shopkart-data-api-1  Started
 Container shopkart-data-db-1  Healthy
 Container shopkart-data-api-1  Healthy
$ curl -s localhost:8000/api/products/9; echo
{"id":9,"name":"Cricket Bat","category":"Sports","price_inr":1999,"stock":15}
```

## 6. A migration as a one-off container

```console
$ cat labs/data/done/migrations/002_add_rating.sql
-- 002: products get a customer rating (0.0 to 5.0). Safe to run more than once.
ALTER TABLE products ADD COLUMN IF NOT EXISTS rating NUMERIC(2,1);
UPDATE products SET rating = CASE id
    WHEN 1 THEN 4.3 WHEN 2 THEN 4.6 WHEN 3 THEN 4.1 WHEN 4 THEN 3.9
    WHEN 5 THEN 4.8 WHEN 6 THEN 4.4 WHEN 7 THEN 4.0 WHEN 8 THEN 4.5
    ELSE 4.0 END
WHERE rating IS NULL;
$ docker compose -f labs/data/done/compose.yaml run --rm migrate
time="2026-11-21T20:11:47Z" level=warning msg="volume \"shopkart-data_db-data\" already exists but was not created by Docker Compose. Use `external: true` to use an existing volume"
 Container shopkart-data-db-1  Running
applying /migrations/002_add_rating.sql
$ curl -s localhost:8000/api/products/2; echo
{"id":2,"name":"Running Shoes","category":"Footwear","price_inr":2499,"stock":25,"rating":4.6}
$ docker compose -f labs/data/done/compose.yaml run --rm migrate
time="2026-11-21T20:11:49Z" level=warning msg="volume \"shopkart-data_db-data\" already exists but was not created by Docker Compose. Use `external: true` to use an existing volume"
 Container shopkart-data-db-1  Running
applying /migrations/002_add_rating.sql
psql:/migrations/002_add_rating.sql:2: NOTICE:  column "rating" of relation "products" already exists, skipping
```

## Clean up

```console
$ docker compose -f labs/data/done/compose.yaml down -v 2>&1 | tail -n 2
 Volume shopkart-data_db-data  Removed
 Network shopkart-data_default  Removed
$ rm -rf backups
```

