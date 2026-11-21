# Lab: The full ShopKart stack with Docker Compose (two parts)

**Part 1:** web (nginx), API, PostgreSQL and Redis in one `compose.yaml`, up with one command.
**Part 2:** health checks and start order, scaling, a tools profile, dev overrides and live reload with `compose watch`.

You write `labs/compose/start/compose.yaml` (TODOs inside). The answers: `done/compose.part1.yaml`, `done/compose.yaml` and `done/compose.override.yaml`.
Paths inside a Compose file are relative to the file, so `../../../app` is the repo's `app/` folder.

```text
browser ──► web (nginx :8080) ──/api──► api (FastAPI :8000) ──► db (PostgreSQL)
                                                           └──► redis (cart)
```

## Part 1

### 1. Up

```bash
docker compose -f labs/compose/start/compose.yaml up -d --build
docker compose -f labs/compose/start/compose.yaml ps
```

Open port **8080** from the Ports tab and add a few things to the cart. Or from the terminal:

```bash
curl -s localhost:8080/health; echo
curl -s -X POST localhost:8080/api/cart/demo/items -H 'Content-Type: application/json' -d '{"product_id": 2, "qty": 1}'; echo
curl -s -X POST localhost:8080/api/cart/demo/items -H 'Content-Type: application/json' -d '{"product_id": 5, "qty": 3}'; echo
```

### 2. Look around

```bash
docker compose -f labs/compose/start/compose.yaml logs api --tail 4
docker compose -f labs/compose/start/compose.yaml exec redis redis-cli hgetall cart:demo
docker compose -f labs/compose/start/compose.yaml exec db psql -U shopkart -c 'SELECT count(*) FROM products;'
docker network ls --filter name=shopkart
```

Compose made a network (`shopkart_default`) where every service is reachable by its service name, which is why `db`, `redis` and `api` just work.

### 3. Down

```bash
docker compose -f labs/compose/start/compose.yaml down
docker volume ls --filter name=shopkart          # the database volume is kept; `down -v` deletes it
```

## Part 2

Work inside the folder from here on, so Compose can find `compose.override.yaml` by itself:

```bash
cd labs/compose/start        # or labs/compose/done
```

### 4. Health checks and start order

With `depends_on: condition: service_healthy`, the API waits for a **healthy** database, and nginx waits for a healthy API. `--wait` returns when everything is healthy.

```bash
docker compose -f compose.yaml up -d --build --wait
docker compose -f compose.yaml ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'
curl -s localhost:8080/api/info; echo
```

### 5. Scale the API

The API has no published port any more (only nginx talks to it), so you can run two:

```bash
docker compose -f compose.yaml up -d --scale api=2 --wait
docker compose -f compose.yaml restart web       # nginx looks up "api" again and finds both
for i in 1 2 3 4; do curl -s localhost:8080/api/info | grep -o '"host":"[a-z0-9]*"'; done
docker compose -f compose.yaml up -d --scale api=1 --wait
```

### 6. A profile

`psql` is in the `tools` profile, so it only runs when you ask for it:

```bash
docker compose -f compose.yaml --profile tools run --rm psql -c 'SELECT id, name, price_inr FROM products LIMIT 3;'
```

### 7. Dev mode with `compose.override.yaml`

Without `-f`, Compose reads `compose.yaml` **and** `compose.override.yaml`. The override bind-mounts your code into the API and runs uvicorn with `--reload`:

```bash
docker compose up -d --wait
docker compose ps api --format '{{.Service}}: {{.Command}}  {{.Ports}}'
curl -s localhost:8000/api/info; echo
```

Now edit `app/api/shopkart_api/main.py` (change `"app": "shopkart-api"`), save, and call it again. Or:

```bash
sed -i 's/"app": "shopkart-api"/"app": "shopkart-api (edited live)"/' ../../../app/api/shopkart_api/main.py
curl -s localhost:8000/api/info; echo
docker compose logs api --tail 6
git checkout -- ../../../app/api/shopkart_api/main.py
```

### 8. `compose watch`

No bind mount this time: `develop.watch` in `compose.yaml` **copies** changed files into the container and restarts it, and rebuilds the image when `requirements.txt` changes.

```bash
docker compose -f compose.yaml up -d --wait
docker compose -f compose.yaml watch
```

In a second terminal, change the code again and call the API through nginx:

```bash
sed -i 's/"app": "shopkart-api"/"app": "shopkart-api (synced by watch)"/' app/api/shopkart_api/main.py
curl -s localhost:8080/api/info; echo
git checkout -- app/api/shopkart_api/main.py
```

Stop `watch` with **Ctrl+C**.

### 9. Clean up

```bash
docker compose down -v
cd -
```

## Checkpoint

- [ ] Products and the cart work on port 8080, with the cart in Redis
- [ ] `ps` shows every service `(healthy)`
- [ ] Two API containers answered through nginx
- [ ] A code change showed up without a rebuild, both with the override and with `watch`
