# Lab: Containerize the ShopKart API (two parts)

**Part 1:** write the first Dockerfile for the API and run it.
**Part 2:** make rebuilds fast, keep junk out of the image, stamp a version, add a health check, and split ENTRYPOINT from CMD.

You write `labs/dockerfile/start/Dockerfile` (TODOs inside). The answers: `done/part1/Dockerfile`, `done/part2/Dockerfile` and `done/part2/Dockerfile.dockerignore`.
The build context is always `app/api` (the API's code), and `-f` points at your Dockerfile.

> The API runs on its own here: with no database settings it uses SQLite in memory and an in-memory cart. PostgreSQL and Redis come in the networking and Compose labs.

## Part 1

### 1. Write the Dockerfile

```dockerfile
FROM python:3.12.16-slim-trixie
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["uvicorn", "shopkart_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### 2. Build and look at the image

```bash
docker build -f labs/dockerfile/start/Dockerfile -t shopkart-api:1.0 app/api
docker images shopkart-api
docker history shopkart-api:1.0
```

`docker history` shows one layer per instruction, on top of the Python image's own layers.

### 3. Run it

```bash
docker run -d --name api -p 8000:8000 shopkart-api:1.0
curl -s localhost:8000/health; echo
curl -s localhost:8000/api/products | head -c 160; echo
docker logs api
docker rm -f api
```

## Part 2

### 4. See the slow rebuild

Change one line of code and build again:

```bash
echo '# a small code change' >> app/api/shopkart_api/main.py
time docker build -f labs/dockerfile/start/Dockerfile -t shopkart-api:1.0 app/api
```

`pip install` runs again (about 15 seconds), because `COPY . .` changed, and every step after a changed step is rebuilt.

### 5. Fix the order, add the rest

Copy `requirements.txt` and install first, then copy the code. Add `ARG`/`ENV APP_VERSION`, `EXPOSE`, `HEALTHCHECK`, and `ENTRYPOINT` + `CMD`. See `done/part2/Dockerfile`.

Add `labs/dockerfile/start/Dockerfile.dockerignore` (Docker uses `<your Dockerfile>.dockerignore` when it sits next to it):

```text
__pycache__/
*.pyc
.pytest_cache/
tests/
*.db
.env
.env.*
Dockerfile*
```

```bash
docker build -f labs/dockerfile/start/Dockerfile --build-arg APP_VERSION=1.1 -t shopkart-api:1.1 app/api
echo '# another small change' >> app/api/shopkart_api/main.py
time docker build -f labs/dockerfile/start/Dockerfile --build-arg APP_VERSION=1.1 -t shopkart-api:1.1 app/api
git checkout -- app/api/shopkart_api/main.py
```

This time the pip step says `CACHED` and the build takes about 2 seconds.

### 6. Healthy, and it knows its version

```bash
docker run -d --name api -p 8000:8000 shopkart-api:1.1
docker ps --filter name=api          # (health: starting) ... then (healthy)
docker inspect api --format '{{.State.Health.Status}} {{(index .State.Health.Log 0).ExitCode}}'
curl -s localhost:8000/api/info; echo
```

### 7. ENTRYPOINT + CMD

CMD only holds the default arguments, so you can replace them without retyping the program:

```bash
docker run -d --name api-9000 -p 9000:9000 shopkart-api:1.1 --host 0.0.0.0 --port 9000 --log-level warning
curl -s localhost:9000/health; echo
docker inspect shopkart-api:1.1 --format 'ENTRYPOINT={{json .Config.Entrypoint}} CMD={{json .Config.Cmd}}'
docker rm -f api api-9000
```

## Checkpoint

- [ ] `shopkart-api:1.0` serves `/api/products`
- [ ] A code-only change rebuilds in seconds (`CACHED` on the pip step)
- [ ] `docker ps` shows `(healthy)` and `/api/info` shows version `1.1`

Keep the `shopkart-api:1.1` image: the next labs use it.
