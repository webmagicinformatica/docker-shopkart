# Lab: Shrink the ShopKart image

Start from a "fat" image (the full Python image plus compilers and tools "just in case", about 1.8 GB on disk) and get it under **150 MB**, measuring size and build time at each step. Then use a BuildKit **cache mount** so a dependency change doesn't re-download every package.

Files: `start/Dockerfile.fat` (the before), `start/Dockerfile` (TODOs). Answers: `done/Dockerfile.slim` (step 1) and `done/Dockerfile` (step 2).

## 1. The fat image

```bash
cat labs/slim-image/start/Dockerfile.fat
time docker build -f labs/slim-image/start/Dockerfile.fat -t shopkart-api:fat app/api
```

## 2. Slim base, no extras

Swap `python:3.12.16-trixie` for `python:3.12.16-slim-trixie`, drop the `apt-get install` line, and copy `requirements.txt` before the code:

```bash
time docker build -f labs/slim-image/done/Dockerfile.slim -t shopkart-api:slim app/api
```

## 3. Multi-stage on Alpine

The build stage installs the packages into a virtualenv. The final stage starts again from a clean Alpine Python and copies only `/venv` and the code. Nothing from the build stage comes along unless you `COPY --from` it.

```bash
time docker build -f labs/slim-image/start/Dockerfile -t shopkart-api:small app/api
```

## 4. Compare

```bash
docker images shopkart-api
docker history shopkart-api:small --format 'table {{.CreatedBy}}\t{{.Size}}' | head -n 6
docker run --rm shopkart-api:fat sh -c 'which gcc git vim curl'
docker run --rm shopkart-api:small sh -c 'which gcc git vim curl; echo exit=$?'
docker run -d --name api-small -p 8000:8000 shopkart-api:small
curl -s localhost:8000/health; echo
docker rm -f api-small
```

`DISK USAGE` is the unpacked size on this machine; `CONTENT SIZE` is the compressed size you push and pull. Fewer tools in the image also means less for an attacker to use, and fewer CVEs (next: the security lab).

| Base | Trade-off |
| --- | --- |
| `python:3.12` (full) | Everything included, huge |
| `python:3.12-slim` | Debian, glibc, small; the safe default |
| `python:3.12-alpine` | Smallest; musl libc, so a few packages without musl wheels need compiling |
| distroless / scratch | No shell or package manager at all; smallest attack surface, harder to debug |

## 5. Cache mounts

Change `requirements.txt` (here, just a comment) and rebuild both:

```bash
echo '# pinned for the Diwali release' >> app/api/requirements.txt
time docker build -f labs/slim-image/done/Dockerfile.slim -t shopkart-api:slim app/api 2>&1 | grep -E -c 'Downloading [a-z]'
time docker build -f labs/slim-image/done/Dockerfile -t shopkart-api:small app/api 2>&1 | grep -c 'Using cached'
git checkout -- app/api/requirements.txt
docker buildx du | tail -n 3
```

Without the cache mount, pip downloads every package again. With `RUN --mount=type=cache,target=/root/.cache/pip`, pip's cache survives between builds but is never part of the image.

Keep `shopkart-api:fat` and `shopkart-api:small`: the security lab scans them.

## Checkpoint

- [ ] `shopkart-api:small` is under 150 MB (DISK USAGE) and still passes `/health`
- [ ] The small image has no compiler, git, vim or curl
- [ ] The cache-mount build printed `Using cached` instead of downloading
