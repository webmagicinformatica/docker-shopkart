# ShopKart: Docker Zero to Pro

**Docker: Zero to Pro · dabeer.ai**

The lab repo for the course. ShopKart is a (fictional) Indian online store: a small FastAPI product and cart API, a static web front end served by nginx, PostgreSQL for the products and Redis for the cart. Over the course you containerize it step by step, run it with Compose, shrink it, secure it and ship it through CI.

```text
browser ──► web (nginx) ──/api──► api (FastAPI) ──► db (PostgreSQL: products)
                                               └──► redis (Redis: carts)
```

| Folder | What's in it |
| --- | --- |
| `app/api` | The API: `shopkart_api/`, `requirements.txt`, `seed.sql`, tests, and the finished `Dockerfile` |
| `app/web`, `app/nginx` | The front end and its nginx config (`app/web/Dockerfile` bakes both into one image) |
| `labs/<lab>/` | One folder per lab: `README.md` (the guide), `start/` (you edit this, look for `TODO`), `done/` (the answer), `RUN.md` (a tested run with real output) |
| `scripts/run-local.sh` | Run ShopKart without Docker |
| `.devcontainer/` | The codespace: Python 3.12, Docker-in-Docker with Compose and buildx, GitHub CLI |

## 1. Get your own copy

1. Click **Use this template** → **Create a new repository**. Name it (e.g. `docker-shopkart`) and create it. Public or private both work.
2. In your new repo: **Code** → **Codespaces** → **Create codespace on main**. It takes a minute or two the first time.
3. In the terminal: `docker version` should print a Client **and** a Server.

New to Codespaces? Watch the "Set up GitHub Codespaces" lab first. Not using Codespaces? Any machine with Docker Engine 25+ (or Docker Desktop), Compose v2 and Python 3.12 works.

## 2. The labs, in order

| Lab | Folder |
| --- | --- |
| Your first container | [`labs/first-container`](labs/first-container) |
| Debug three broken containers | [`labs/debug-containers`](labs/debug-containers) |
| Containerize the API (Part 1 and 2) | [`labs/dockerfile`](labs/dockerfile) |
| Tag, push and pull (local registry + GHCR) | [`labs/registry`](labs/registry) |
| Networking and storage | [`labs/network-storage`](labs/network-storage) |
| The full stack with Compose (Part 1 and 2) | [`labs/compose`](labs/compose) |
| Configuration and secrets | [`labs/config-secrets`](labs/config-secrets) |
| Shrink the image | [`labs/slim-image`](labs/slim-image) |
| Back up, restore, migrate | [`labs/data`](labs/data) |
| Scan and harden (Part 1 and 2) | [`labs/security`](labs/security) |
| Production habits: a leak and a slow container | [`labs/production`](labs/production) |
| CI/CD: pipeline and deploy (Part 1 and 2) | [`labs/ci-cd`](labs/ci-cd) |

Run every command from the repo root unless the guide says `cd`. Each guide ends with a clean-up step: run it, so the next lab starts fresh.

## 3. Run ShopKart without Docker

```bash
./scripts/run-local.sh          # then open port 8000
```

It uses SQLite and an in-memory cart when `DATABASE_URL` and `REDIS_URL` aren't set. That's on purpose: it's the "works on my machine" version that the course replaces.

## 4. Tests

```bash
cd app/api && pytest -q
```

No database, no Redis, no network. The same tests run in GitHub Actions (`.github/workflows/ci.yml`), which also builds the image and checks the whole stack with Compose.

## Get new labs

Your copy doesn't update by itself. Link it to the course repo once, then pull.

**One time only** (in your codespace terminal):

```bash
git remote add upstream https://github.com/webmagicinformatica/docker-shopkart.git
git config pull.rebase false
git pull upstream main --allow-unrelated-histories -X theirs --no-edit
git push
```

Why the extra flags? "Use this template" gives your repo a fresh history, so Git sees the course repo as unrelated and refuses to merge without `--allow-unrelated-histories`. On this first pull, `-X theirs` takes the course's version of any file both sides have changed; files you created yourself are kept.

**Every time after that:**

```bash
git pull upstream main --no-edit
```

Commit your own work first (`git add -A && git commit -m "..."`). Work inside `labs/<lab>/start/` and you won't get conflicts. Each lab's `done/` folder has the finished version if you get stuck.

---

MIT licensed · [dabeer.ai on YouTube](https://www.youtube.com/@dabeer.ai)
