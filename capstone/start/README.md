# QuickBite

A small (fictional) food-order tracker: customers order from a menu, a kitchen worker cooks each order, and the page shows it move from **received** to **preparing** to **ready**.

```text
browser ──► web (nginx, static files) ──/api──► api (Node.js) ──► db (PostgreSQL: menu, orders)
                                                     │                   ▲
                                                     └─► redis (queue) ──► worker (Python) updates the status
```

| Folder | What it is |
| --- | --- |
| `api/` | Orders API, Node.js 24, no framework (`pg` and `redis` are the only dependencies). Creates its tables and the menu on start. |
| `worker/` | Kitchen worker, Python 3.12. Takes order IDs off the Redis list `quickbite:orders` and sets the order status in PostgreSQL. |
| `web/` | Static front end (HTML, CSS, JS) and `nginx.conf` for serving it and passing `/api/` to `api:3000`. |
| `run-local.sh` | Run it without Docker (see below). |

## Run it without Docker

```bash
./run-local.sh        # needs Node.js 24; open port 3000
```

Without `PGHOST` the API keeps orders in memory, and without `REDIS_URL` it cooks them itself (a fake kitchen), so the worker isn't used. That's the "works on my machine" version.

## Tests

```bash
cd api && npm ci && npm test                                    # node --test, no database or Redis
cd worker && pip install -r requirements-dev.txt && pytest -q   # fakes, no database or Redis
```

## Configuration (environment variables)

| Variable | Used by | Default | Meaning |
| --- | --- | --- | --- |
| `PORT` | api | `3000` | Port the API listens on |
| `APP_ENV` | api | `local` | Shown by `/api/info` |
| `APP_VERSION` | api | `dev` | Shown by `/api/info` |
| `PGHOST`, `PGPORT`, `PGUSER`, `PGDATABASE` | api, worker | unset (api), `localhost` (worker), `5432`, `quickbite`, `quickbite` | PostgreSQL connection. No `PGHOST` = in-memory store (API only) |
| `PGPASSWORD` | api, worker | unset | Database password as plain text (avoid) |
| `PGPASSWORD_FILE` | api, worker | unset | Path of a file holding the password (wins over `PGPASSWORD`) |
| `REDIS_URL` | api, worker | unset (api), `redis://localhost:6379/0` (worker) | The order queue. No `REDIS_URL` = fake kitchen in the API |
| `KITCHEN_SECONDS` | api, worker | `3` | How long cooking takes |
| `HEARTBEAT_FILE` | worker | `/tmp/quickbite-worker.heartbeat` | Touched at least every 5 seconds while the worker is healthy |
| `WEB_DIR` | api | unset | Without Docker only: serve the front end from this folder |

## Endpoints

| Method and path | Answer |
| --- | --- |
| `GET /health` | `200 {"status":"ok","db":"ok","queue":"ok"}`, or `503` with the part that's down |
| `GET /api/info` | App, version, environment, store, queue, host name |
| `GET /api/menu` | The six dishes |
| `POST /api/orders` | Body `{"customer":"Asha","items":[{"menu_id":1,"qty":2}]}` → `201` with the order |
| `GET /api/orders/<id>` | One order |
| `GET /api/orders?limit=10` | Recent orders, newest first |

The worker exits cleanly on `SIGTERM` after finishing the order in hand; the API stops accepting connections and closes its pools.
