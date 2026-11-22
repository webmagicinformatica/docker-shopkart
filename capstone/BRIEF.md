# Capstone: containerize and ship QuickBite

**Docker: Zero to Pro · dabeer.ai**

QuickBite is a small food-order tracker. Its team has a working app and no containers: it runs on one laptop with `./run-local.sh`, and nobody else can run the real thing (PostgreSQL, Redis, a Python worker) without an afternoon of setup. Your job: **containerize every service, run the whole stack with one command, harden it, and ship it through CI**, using everything from the course.

```text
browser ──► web (nginx :8080) ──/api──► api (Node.js :3000) ──► db (PostgreSQL)
                                              │                    ▲
                                              └─► redis (queue) ──► worker (Python)
```

It's a new app on purpose: ShopKart answers won't fit. Read [`start/README.md`](start/README.md) first: it lists every environment variable and endpoint the app has.

| Folder or file | What it is |
| --- | --- |
| `start/` | The app, no Docker files. **You work here.** |
| `check.sh` | The acceptance checks: one PASS or FAIL per requirement below |
| `done/` | The reference solution. Don't open it until you've finished (or are truly stuck) |
| `RUN.md` | A tested run of `check.sh` against `done/` and `start/`, and the reference pipeline on GitHub Actions |

## 0. Before you start

```bash
git pull upstream main --no-edit        # get the capstone (see the README if upstream isn't set up)
cd capstone/start
./run-local.sh                           # the "before": open port 3000, place an order, Ctrl+C
cd api && npm ci && npm test && cd ..    # 8 tests
cd worker && pip install -r requirements-dev.txt && python -m pytest -q && cd ..   # 5 tests
```

Then run the checks once to see where you stand (everything fails, that's the point):

```bash
cd /workspaces/docker-shopkart           # the repo root
./capstone/check.sh                      # checks capstone/start
```

## 1. What to build

Everything goes in `capstone/start/`. Each line below is checked by `check.sh` (the number is the check's number).

### Images

| # | Requirement |
| --- | --- |
| 1 | `api/Dockerfile`, `worker/Dockerfile` and `web/Dockerfile`, each with a `.dockerignore` (keep `node_modules`, caches and secrets out of the build context). |
| 2 | **Multi-stage** builds for `api` and `worker`, with a stage named **`test`** and a final stage named **`runtime`**. Build tools and dev dependencies stay out of `runtime`. The web image has no build step, so one stage is fine. |
| 3 | `docker build --target test api` and `docker build --target test worker` run the unit tests and fail the build if a test fails. |
| 4 | `docker compose build` succeeds. |
| 5 | **Pinned versions:** every `FROM` and every `image:` has an exact version tag (like `postgres:17.12-alpine3.24`) or a digest. No `latest`, no bare `node`. Lock files (`package-lock.json`, `requirements*.txt`) are already pinned: use them (`npm ci`, `pip install -r`). |
| 6 | **Small:** api ≤ 300 MB, worker ≤ 200 MB, web ≤ 150 MB (the DISK USAGE column of `docker images`). |
| 7 | **Non-root:** each image sets `USER` to an unprivileged user (a numeric UID is safest). |
| 8 | **Health checks** that mean something, in each image: the api's `/health` checks PostgreSQL and Redis; the worker has no port, but it touches `HEARTBEAT_FILE` at least every 5 seconds while it can reach Redis; nginx answers `/health` itself. Use tools that exist in your image (no `curl` in Alpine unless you add it). |

### Compose

| # | Requirement |
| --- | --- |
| 9 | One `compose.yaml` in `start/` with exactly these service names: `web`, `api`, `worker`, `db`, `redis`. Give each app service a `build:` and an `image:` (for example `quickbite-api:${TAG:-local}`). The web container listens on **8080**. |
| 10 | **Health-gated start:** every service is healthy-checked (in the image or in Compose), and every `depends_on` uses `condition: service_healthy`: api waits for db and redis, worker for db and redis, web for api. Hint: the api creates the tables on start, so the worker should wait for it too. |
| 11 | **Named volumes** for PostgreSQL (`/var/lib/postgresql/data`) and Redis (`/data`, with `--appendonly yes`) so orders survive a restart. |
| 12 | **Networks:** only `web` publishes a port; `db` and `redis` share no network with `web` (two networks: a front one and a back one; `internal: true` on the back one is a bonus). Publish web as `"${WEB_PORT:-8080}:8080"` so the checker can pick a free port. |
| 13 | **Config and secrets:** the database password is a **Compose secret** from a file (`secrets/db_password.txt`, already git-ignored by the repo's `.gitignore`), passed with `POSTGRES_PASSWORD_FILE` and `PGPASSWORD_FILE`. No `*PASSWORD` variable with a value anywhere, and the password in no image. Everything else that differs between environments comes from variables with defaults (`${KITCHEN_SECONDS:-3}`), documented in a committed `.env.example` (`.env` itself is never committed). |

Make the secret once: `mkdir -p secrets && openssl rand -hex 16 > secrets/db_password.txt`. Keep it readable (`644`): the containers' users must be able to read the bind-mounted file. `check.sh` makes a random one if it's missing.

### The running stack

| # | Requirement |
| --- | --- |
| 14 | `docker compose up -d --build --wait` succeeds and all five services report **healthy**. |
| 15 | An order placed through **web** (`POST /api/orders` on port 8080) is cooked by the worker: its status reaches `ready` within 30 seconds. |
| 16 | The order is still there after `docker compose down` and `up` again (no `-v`). |

### Hardening (checked on the running containers)

| # | Requirement |
| --- | --- |
| 17 | `read_only: true` on all five services. Give each a `tmpfs` where it must write (`/tmp`; PostgreSQL also needs `/var/run/postgresql`). |
| 18 | `cap_drop: [ALL]` on all five. |
| 19 | `security_opt: ["no-new-privileges:true"]` on all five. |
| 20 | A memory limit (`mem_limit`) and a PID limit (`pids_limit`) on all five. A YAML anchor (`x-hardening: &hardening`) saves a lot of typing. |
| 21 | No process in any container runs as uid 0. For `db` and `redis`, set `user: postgres` and `user: redis` (their entrypoints only need root to fix file ownership, which the named volumes don't need). |

### Development

| # | Requirement |
| --- | --- |
| 22 | A `compose.dev.yaml` override with `develop.watch` for `api`, `worker` and `web`: `sync+restart` for the api and worker code, `sync` for the web files, `rebuild` when dependencies change. `docker compose -f compose.yaml -f compose.dev.yaml watch` must pick up an edit to `web/index.html` live. (Watch copies files into the container, so the dev override turns `read_only` off.) |

### Security scan

| # | Requirement |
| --- | --- |
| 23 | **Trivy** finds **zero HIGH or CRITICAL vulnerabilities that have a fix** (`--ignore-unfixed`) in the api, worker and web images. Patch the OS packages, keep the runtime stage minimal, and remember that tools you don't ship (npm, pip) can't have CVEs. Results change daily: a pass today can be a fail next week, which is exactly why it's in the pipeline. |

### CI/CD

| # | Requirement |
| --- | --- |
| 24 | A `pipeline.yml` in `start/` for GitHub Actions that: runs the api and worker **tests**; **builds** the three images with the GitHub Actions **layer cache** (`cache-from: type=gha`); **scans** them with Trivy and **fails** on fixable HIGH/CRITICAL (`--exit-code 1`); and **pushes** them to `ghcr.io/<owner>/quickbite-<service>` with `GITHUB_TOKEN` (`permissions: packages: write`), but not from pull requests. Pin every action to a version tag. |

Then copy it into place, push, and watch it run:

```bash
cp capstone/start/pipeline.yml .github/workflows/quickbite.yml
git add -A && git commit -m "QuickBite: containers, compose, pipeline" && git push
gh run watch                              # or the Actions tab
```

The course repo's own `.github/workflows/capstone.yml` runs the reference solution and only runs in the course repo, so it shows as skipped in yours.

## 2. Check your work

```bash
./capstone/check.sh                       # about 3 to 5 minutes; the first Trivy run downloads its database
SKIP_SCAN=1 ./capstone/check.sh           # faster while you iterate (check 23 then shows FAIL)
```

It builds your images, starts the stack as a separate project (`qbcheck`, web on port 18080) so it doesn't touch yours, places an order, restarts the stack, inspects the containers, tries `compose watch`, scans, reads `pipeline.yml`, and removes everything it started (containers, networks, volumes). The exit code is 0 only when all 24 checks pass.

Two things it can't see: your pipeline **ran green** on GitHub Actions, and the three images **are in GHCR** (your profile → Packages). Check those by hand.

## 3. Self-check rubric

`check.sh` tells you whether it works. This tells you whether it's good. Score yourself 0, 1 or 2 per row.

| Area | 0 | 1 | 2 |
| --- | --- | --- | --- |
| **Build cache** | Code is copied before dependencies: every edit reinstalls everything | Lock file first, then install, then code | Plus BuildKit cache mounts for npm/pip, and a rebuild after a code edit takes seconds |
| **Build context** | No `.dockerignore`, or it misses `node_modules` | The usual suspects ignored | Context is tiny; nothing secret or local (`.env`, `secrets/`, caches) can ever reach it |
| **Runtime image** | Full base image, build tools inside | Slim or Alpine base | Only what runs: no npm, pip, compilers or tests in `runtime`; OS packages patched |
| **Health checks** | None, or "is the process alive" | Each service checks its own endpoint | Each check proves the service can do its job (api: db + queue; worker: heartbeat), with sensible intervals and start periods |
| **Start order and restarts** | `depends_on` without conditions; races on first start | Health-gated | Plus `restart:` policy, and `docker compose up --wait` is reliable from an empty machine |
| **Config and secrets** | Passwords in `compose.yaml` or the image | Secrets from files | One image for every environment; every setting has a default and is in `.env.example`; `docker history` shows no secret |
| **Hardening** | Defaults | Read-only, no capabilities, no new privileges | Plus non-root everywhere, memory and PID limits, log rotation, and only web reachable from outside |
| **Graceful stop** | `docker compose stop` waits the full 10 seconds | Exits on SIGTERM | Exec-form `CMD` so the app is PID 1 and gets the signal; the worker finishes the order in hand (try it: `time docker compose stop worker`) |
| **Dev loop** | Rebuild for every change | Bind mounts | `compose watch`: code syncs, the app restarts, and dependency changes rebuild |
| **Pipeline** | Builds only | Tests, builds, pushes | Tests → cached build → scan gate → push; tags by commit SHA plus `latest` on main; nothing pushed from PRs; actions pinned |

**18 to 20:** production-ready. **12 to 17:** works, polish the 1s. **Below 12:** revisit the matching module's lab.

## 4. Stretch goals

- Build the api and worker for **amd64 and arm64** with `docker buildx` and push a multi-platform image.
- Export an **SBOM** for each image in the pipeline and upload it as a build artifact.
- **Sign** the pushed images with Sigstore `cosign` (keyless, from Actions).
- Add a **tools profile** with a one-off `psql` service, and a backup command for the `db-data` volume.
- **Deploy** the stack to a server from the pipeline, as in the CI/CD lab's Part 2.

## 5. Clean up

```bash
cd capstone/start && docker compose -f compose.yaml -f compose.dev.yaml down -v   # your own stack and its volumes
```

`check.sh` cleans up after itself. Compare with `done/` only after you've scored yourself, and read its comments: they explain each choice.
