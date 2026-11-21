# The full ShopKart stack with Docker Compose (two parts): tested run

Recorded on 2026-11-21 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings and sizes will differ.

## Part 1. Up

```console
$ docker compose -f labs/compose/done/compose.part1.yaml up -d --build
[... 201 earlier lines of output cut ...]
#15 DONE 3.1s

#16 resolving provenance for metadata file
#16 DONE 0.0s
 shopkart-api:compose  Built
 Network shopkart_default  Creating
 Network shopkart_default  Created
 Volume shopkart_db-data  Creating
 Volume shopkart_db-data  Created
 Container shopkart-redis-1  Creating
 Container shopkart-db-1  Creating
 Container shopkart-redis-1  Created
 Container shopkart-db-1  Created
 Container shopkart-api-1  Creating
 Container shopkart-api-1  Created
 Container shopkart-web-1  Creating
 Container shopkart-web-1  Created
 Container shopkart-redis-1  Starting
 Container shopkart-db-1  Starting
 Container shopkart-redis-1  Started
 Container shopkart-db-1  Started
 Container shopkart-api-1  Starting
 Container shopkart-api-1  Started
 Container shopkart-web-1  Starting
 Container shopkart-web-1  Started
$ docker compose -f labs/compose/done/compose.part1.yaml ps
NAME               IMAGE                   COMMAND                  SERVICE   CREATED         STATUS                                     PORTS
shopkart-api-1     shopkart-api:compose    "uvicorn shopkart_ap…"   api       2 seconds ago   Up Less than a second (health: starting)   0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp
shopkart-db-1      postgres:17.12-alpine   "docker-entrypoint.s…"   db        3 seconds ago   Up 1 second                                5432/tcp
shopkart-redis-1   redis:8.8.4-alpine      "docker-entrypoint.s…"   redis     3 seconds ago   Up 1 second                                6379/tcp
shopkart-web-1     nginx:1.30.7-alpine     "/docker-entrypoint.…"   web       2 seconds ago   Up Less than a second                      0.0.0.0:8080->80/tcp, [::]:8080->80/tcp
$ curl -s localhost:8080/health; echo
{"status":"ok","db":"ok","cart":"ok"}
$ curl -s -X POST localhost:8080/api/cart/demo/items -H 'Content-Type: application/json' -d '{"product_id": 2, "qty": 1}'; echo
{"cart_id":"demo","items":[{"product_id":2,"name":"Running Shoes","qty":1,"price_inr":2499,"line_total_inr":2499}],"total_inr":2499}
$ curl -s -X POST localhost:8080/api/cart/demo/items -H 'Content-Type: application/json' -d '{"product_id": 5, "qty": 3}'; echo
{"cart_id":"demo","items":[{"product_id":2,"name":"Running Shoes","qty":1,"price_inr":2499,"line_total_inr":2499},{"product_id":5,"name":"Masala Chai Tin","qty":3,"price_inr":299,"line_total_inr":897}],"total_inr":3396}
```

## Part 1. Look around

```console
$ docker compose -f labs/compose/done/compose.part1.yaml logs api --tail 4
api-1  | INFO:     127.0.0.1:53310 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     172.19.0.5:33746 - "GET /health HTTP/1.1" 200 OK
api-1  | INFO:     172.19.0.5:33752 - "POST /api/cart/demo/items HTTP/1.1" 201 Created
api-1  | INFO:     172.19.0.5:33756 - "POST /api/cart/demo/items HTTP/1.1" 201 Created
$ docker compose -f labs/compose/done/compose.part1.yaml exec redis redis-cli hgetall cart:demo
2
1
5
3
$ docker compose -f labs/compose/done/compose.part1.yaml exec db psql -U shopkart -c 'SELECT count(*) FROM products;'
 count 
-------
     8
(1 row)

$ docker network ls --filter name=shopkart
NETWORK ID     NAME               DRIVER    SCOPE
f9ae16dbffed   shopkart_default   bridge    local
```

## Part 1. Down (the volume stays)

```console
$ docker compose -f labs/compose/done/compose.part1.yaml down
 Container shopkart-web-1  Stopping
 Container shopkart-web-1  Stopped
 Container shopkart-web-1  Removing
 Container shopkart-web-1  Removed
 Container shopkart-api-1  Stopping
 Container shopkart-api-1  Stopped
 Container shopkart-api-1  Removing
 Container shopkart-api-1  Removed
 Container shopkart-db-1  Stopping
 Container shopkart-redis-1  Stopping
 Container shopkart-db-1  Stopped
 Container shopkart-db-1  Removing
 Container shopkart-redis-1  Stopped
 Container shopkart-redis-1  Removing
 Container shopkart-db-1  Removed
 Container shopkart-redis-1  Removed
 Network shopkart_default  Removing
 Network shopkart_default  Removed
$ docker volume ls --filter name=shopkart
DRIVER    VOLUME NAME
local     shopkart_db-data
```

## Part 2. Health checks and start order

```console
$ cd labs/compose/done && docker compose -f compose.yaml up -d --build --wait 2>&1 | tail -n 12
 Container shopkart-api-1  Waiting
 Container shopkart-api-1  Healthy
 Container shopkart-web-1  Starting
 Container shopkart-web-1  Started
 Container shopkart-db-1  Waiting
 Container shopkart-redis-1  Waiting
 Container shopkart-web-1  Waiting
 Container shopkart-api-1  Waiting
 Container shopkart-api-1  Healthy
 Container shopkart-db-1  Healthy
 Container shopkart-redis-1  Healthy
 Container shopkart-web-1  Healthy
$ cd labs/compose/done && docker compose -f compose.yaml ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
SERVICE   STATUS                    PORTS
api       Up 16 seconds (healthy)   8000/tcp
db        Up 22 seconds (healthy)   5432/tcp
redis     Up 22 seconds (healthy)   6379/tcp
web       Up 10 seconds (healthy)   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp
$ curl -s localhost:8080/api/info; echo
{"app":"shopkart-api","version":"1.2","env":"compose","db":"postgres","banner":"","host":"a85467f7e9af"}
```

## Part 2. Scale the API

```console
$ cd labs/compose/done && docker compose -f compose.yaml up -d --scale api=2 --wait 2>&1 | tail -n 3
 Container shopkart-db-1  Healthy
 Container shopkart-api-2  Healthy
 Container shopkart-api-1  Healthy
$ cd labs/compose/done && docker compose -f compose.yaml restart web
 Container shopkart-web-1  Restarting
 Container shopkart-web-1  Started
$ for i in 1 2 3 4; do curl -s localhost:8080/api/info | grep -o '"host":"[a-z0-9]*"'; done
"host":"ac46370172b9"
"host":"ac46370172b9"
"host":"a85467f7e9af"
"host":"ac46370172b9"
$ cd labs/compose/done && docker compose -f compose.yaml up -d --scale api=1 --wait 2>&1 | tail -n 2
 Container shopkart-redis-1  Healthy
 Container shopkart-web-1  Healthy
```

## Part 2. A profile: tools that only start when asked

```console
$ cd labs/compose/done && docker compose -f compose.yaml --profile tools run --rm psql -c 'SELECT id, name, price_inr FROM products LIMIT 3;'
 Container shopkart-db-1  Running
 id |        name        | price_inr 
----+--------------------+-----------
  1 | Cotton Kurta       |       899
  2 | Running Shoes      |      2499
  3 | Steel Water Bottle |       549
(3 rows)

```

## Part 2. Dev mode: compose.override.yaml

```console
$ cd labs/compose/done && docker compose config --services && docker compose up -d --wait 2>&1 | tail -n 3
db
redis
api
web
 Container shopkart-redis-1  Healthy
 Container shopkart-api-1  Healthy
 Container shopkart-db-1  Healthy
$ cd labs/compose/done && docker compose ps api --format '{{.Service}}: {{.Command}}  {{.Ports}}'
api: "uvicorn shopkart_ap…"  0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp
$ curl -s localhost:8000/api/info; echo
{"app":"shopkart-api","version":"1.2","env":"dev","db":"postgres","banner":"","host":"db5ddcd09f64"}
$ sed -i 's/"app": "shopkart-api"/"app": "shopkart-api (edited live)"/' app/api/shopkart_api/main.py
$ curl -s localhost:8000/api/info; echo
{"app":"shopkart-api (edited live)","version":"1.2","env":"dev","db":"postgres","banner":"","host":"db5ddcd09f64"}
$ cd labs/compose/done && docker compose logs api --tail 6
api-1  | INFO:     Finished server process [7]
api-1  | INFO shopkart: ShopKart 1.2 starting (env=dev, db=postgres)
api-1  | INFO:     Started server process [14]
api-1  | INFO:     Waiting for application startup.
api-1  | INFO:     Application startup complete.
api-1  | INFO:     172.19.0.1:43524 - "GET /api/info HTTP/1.1" 200 OK
$ git checkout -- app/api/shopkart_api/main.py
```

## Part 2. compose watch

Back to the plain compose.yaml (no bind mount). Terminal 1:

```console
$ cd labs/compose/done && docker compose -f compose.yaml up -d --wait 2>&1 | tail -n 2
 Container shopkart-api-1  Healthy
 Container shopkart-redis-1  Healthy
$ cd labs/compose/done && timeout 45 docker compose -f compose.yaml watch
#1 [internal] load local bake definitions
#1 reading from stdin 575B done
#1 DONE 0.0s

#2 [internal] load build definition from Dockerfile
#2 transferring dockerfile: 1.30kB done
#2 DONE 0.0s

#3 resolve image config for docker-image://docker.io/docker/dockerfile:1
#3 DONE 0.6s

#4 docker-image://docker.io/docker/dockerfile:1@sha256:572cebbc2b15e6f84c077742952674889cb63cd5e9b80abdffcbe587b6f19183
#4 resolve docker.io/docker/dockerfile:1@sha256:572cebbc2b15e6f84c077742952674889cb63cd5e9b80abdffcbe587b6f19183 0.0s done
#4 CACHED

#5 [internal] load metadata for docker.io/library/python:3.12.16-alpine3.24
#5 DONE 0.9s

#6 [internal] load build context
#6 transferring context: 5.09kB done
#6 DONE 0.0s

#7 [build 1/4] FROM docker.io/library/python:3.12.16-alpine3.24@sha256:c5ba3deef00c7758561a0f03c26f44f10589263d40e732b8748e0d1f38f6dd89
#7 resolve docker.io/library/python:3.12.16-alpine3.24@sha256:c5ba3deef00c7758561a0f03c26f44f10589263d40e732b8748e0d1f38f6dd89 0.1s done
#7 DONE 0.1s

#8 [build 4/4] RUN /venv/bin/pip install -r requirements.txt
#8 CACHED

#9 [stage-1 2/5] RUN apk upgrade --no-cache && adduser -S -u 10001 -H shopkart
#9 CACHED

#10 [stage-1 3/5] WORKDIR /app
#10 CACHED

#11 [build 2/4] RUN python -m venv /venv
#11 CACHED

#12 [build 3/4] COPY requirements.txt .
#12 CACHED

#13 [stage-1 4/5] COPY --from=build /venv /venv
#13 CACHED

#14 [stage-1 5/5] COPY --chown=root:root . .
#14 CACHED

#15 exporting to image
#15 exporting layers done
#15 exporting manifest sha256:ef41236bc57b3c838c4b23ee45e44732fde05d49329daf3b66293f1b275759aa done
#15 exporting config sha256:4fed8007e19e7d91f8dfe8d745c13370d6fa222c0b8d71d88c805b3ee080ddff done
#15 exporting attestation manifest sha256:3d10cbfd550f387a29011dd8927614dfa7fecdf0b948cee479449ab953962b35
#15 exporting attestation manifest sha256:3d10cbfd550f387a29011dd8927614dfa7fecdf0b948cee479449ab953962b35 0.0s done
#15 exporting manifest list sha256:aa2dccbf1b49037756fa062f4023636bf980751643e7dd70beecdda72c3d812a 0.0s done
#15 naming to docker.io/library/shopkart-api:compose done
#15 unpacking to docker.io/library/shopkart-api:compose 0.0s done
#15 DONE 0.2s

#16 resolving provenance for metadata file
#16 DONE 0.0s
 shopkart-api:compose  Built
 Container shopkart-redis-1  Running
 Container shopkart-db-1  Running
 Container shopkart-api-1  Recreate
 Container shopkart-api-1  Recreated
 Container shopkart-web-1  Running
 Container shopkart-redis-1  Waiting
 Container shopkart-db-1  Waiting
 Container shopkart-db-1  Healthy
 Container shopkart-redis-1  Healthy
 Container shopkart-api-1  Starting
 Container shopkart-api-1  Started
 Container shopkart-api-1  Waiting
 Container shopkart-api-1  Healthy
Watch enabled
Syncing service "api" after 2 changes were detected
service(s) ["api"] restarted
Syncing service "api" after 1 changes were detected
service(s) ["api"] restarted

```

Terminal 2, while watch runs:

```console
$ sed -i 's/"app": "shopkart-api"/"app": "shopkart-api (synced by watch)"/' app/api/shopkart_api/main.py
$ curl -s localhost:8080/api/info; echo
{"app":"shopkart-api (synced by watch)","version":"1.2","env":"compose","db":"postgres","banner":"","host":"f788f3fccf67"}
$ git checkout -- app/api/shopkart_api/main.py
```

## Clean up

```console
$ cd labs/compose/done && docker compose down -v
 Container shopkart-web-1  Stopping
 Container shopkart-web-1  Stopped
 Container shopkart-web-1  Removing
 Container shopkart-web-1  Removed
 Container shopkart-api-1  Stopping
 Container shopkart-api-1  Stopped
 Container shopkart-api-1  Removing
 Container shopkart-api-1  Removed
 Container shopkart-redis-1  Stopping
 Container shopkart-db-1  Stopping
 Container shopkart-redis-1  Stopped
 Container shopkart-redis-1  Removing
 Container shopkart-db-1  Stopped
 Container shopkart-db-1  Removing
 Container shopkart-redis-1  Removed
 Container shopkart-db-1  Removed
 Network shopkart_default  Removing
 Volume shopkart_db-data  Removing
 Volume shopkart_db-data  Removed
 Network shopkart_default  Removed
```

