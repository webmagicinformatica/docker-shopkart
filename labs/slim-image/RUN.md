# Shrink the ShopKart image: tested run

Recorded on 2026-11-21 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings and sizes will differ.

## 1. The fat image

```console
$ cat labs/slim-image/done/Dockerfile.fat
# The "before" image: the full Python image, compilers and tools "just in case", everything in one stage.
FROM python:3.12.16-trixie
RUN apt-get update && apt-get install -y build-essential git vim curl
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["uvicorn", "shopkart_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
$ time docker build -f labs/slim-image/done/Dockerfile.fat -t shopkart-api:fat app/api
[... 44 earlier lines of output cut ...]
#10 unpacking to docker.io/library/shopkart-api:fat 0.0s done
#10 DONE 0.2s

real	0m1.074s
user	0m0.103s
sys	0m0.056s
```

## 2. Slim base, no extras

```console
$ time docker build -f labs/slim-image/done/Dockerfile.slim -t shopkart-api:slim app/api
[... 41 earlier lines of output cut ...]
#10 unpacking to docker.io/library/shopkart-api:slim 0.0s done
#10 DONE 0.2s

real	0m1.027s
user	0m0.090s
sys	0m0.069s
```

## 3. Multi-stage on Alpine

```console
$ cat labs/slim-image/done/Dockerfile
# syntax=docker/dockerfile:1
# Step 2: multi-stage on Alpine. The build stage installs into a virtualenv; the final stage
# copies only that venv and the code. A BuildKit cache mount keeps pip's downloads between builds.

FROM python:3.12.16-alpine3.24 AS build
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
RUN python -m venv /venv
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    /venv/bin/pip install -r requirements.txt

FROM python:3.12.16-alpine3.24
ENV PATH=/venv/bin:$PATH PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY --from=build /venv /venv
COPY . .
CMD ["uvicorn", "shopkart_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
$ time docker build -f labs/slim-image/done/Dockerfile -t shopkart-api:small app/api
[... 54 earlier lines of output cut ...]
#14 unpacking to docker.io/library/shopkart-api:small 0.0s done
#14 DONE 0.2s

real	0m2.301s
user	0m0.095s
sys	0m0.068s
```

## 4. Compare

```console
$ docker images shopkart-api
IMAGE                  ID             DISK USAGE   CONTENT SIZE   EXTRA
shopkart-api:1.0       140a334004c3        264MB         69.3MB        
shopkart-api:1.1       35a53779dedd        240MB         58.4MB        
shopkart-api:1.2       3fffe7c7c1c0        141MB         33.7MB        
shopkart-api:compose   45baec729461        141MB         33.7MB        
shopkart-api:fat       d1743ee47d65        1.8GB          470MB        
shopkart-api:slim      33da9464583a        241MB         58.4MB        
shopkart-api:small     aa7522f85ac9        141MB         33.7MB        
$ docker history shopkart-api:small --format 'table {{.CreatedBy}}\t{{.Size}}' | head -n 6
CREATED BY                                      SIZE
CMD ["uvicorn" "shopkart_api.main:app" "--ho…   0B
COPY . . # buildkit                             156kB
COPY /venv /venv # buildkit                     51.4MB
WORKDIR /app                                    8.19kB
ENV PATH=/venv/bin:/usr/local/bin:/usr/local…   0B
$ docker run --rm shopkart-api:fat sh -c 'which gcc git vim curl'
/usr/bin/gcc
/usr/bin/git
/usr/bin/vim
/usr/bin/curl
$ docker run --rm shopkart-api:small sh -c 'which gcc git vim curl; echo exit=$?'
exit=1
$ docker run -d --name api-small -p 8000:8000 shopkart-api:small
832c677706f001c8f4fc942b9273a1702a550f69a62869457efee6d2fd563b76
$ curl -s localhost:8000/health; echo
{"status":"ok","db":"ok","cart":"ok"}
$ docker rm -f api-small
api-small
```

## 5. Cache mounts: a dependency change without re-downloading

```console
$ echo '# pinned for the Diwali release' >> app/api/requirements.txt
$ time docker build -f labs/slim-image/done/Dockerfile.slim -t shopkart-api:slim app/api 2>&1 | grep -E -c 'Downloading [a-z]'
34

real	0m17.176s
user	0m0.126s
sys	0m0.079s
$ time docker build -f labs/slim-image/done/Dockerfile -t shopkart-api:small app/api 2>&1 | grep -E 'Using cached|Downloading [a-z]' | head -n 5
#10 1.065   Using cached fastapi-0.165.0-py3-none-any.whl.metadata (27 kB)
#10 1.222   Using cached uvicorn-0.54.0-py3-none-any.whl.metadata (6.6 kB)
#10 1.350   Using cached psycopg-3.3.9-py3-none-any.whl.metadata (4.4 kB)
#10 1.516   Using cached redis-8.1.0-py3-none-any.whl.metadata (16 kB)
#10 1.656   Using cached starlette-1.10.0-py3-none-any.whl.metadata (6.6 kB)

real	0m14.492s
user	0m0.119s
sys	0m0.074s
$ git checkout -- app/api/requirements.txt
$ docker buildx du | tail -n 3
Private:	552.4MB
Reclaimable:	3.016GB
Total:		3.016GB
```

