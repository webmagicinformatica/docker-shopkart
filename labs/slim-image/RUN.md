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
[... 263 earlier lines of output cut ...]
#10 unpacking to docker.io/library/shopkart-api:fat 12.4s done
#10 DONE 17.3s

real	1m4.210s
user	0m0.190s
sys	0m0.120s
```

## 2. Slim base, no extras

```console
$ time docker build -f labs/slim-image/done/Dockerfile.slim -t shopkart-api:slim app/api
[... 100 earlier lines of output cut ...]
#10 unpacking to docker.io/library/shopkart-api:slim 0.5s done
#10 DONE 2.9s

real	0m19.228s
user	0m0.136s
sys	0m0.075s
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
[... 113 earlier lines of output cut ...]
#14 unpacking to docker.io/library/shopkart-api:small 0.6s done
#14 DONE 3.5s

real	0m29.272s
user	0m0.170s
sys	0m0.100s
```

## 4. Compare

```console
$ docker images shopkart-api
IMAGE                  ID             DISK USAGE   CONTENT SIZE   EXTRA
shopkart-api:1.0       62aaa0e3d372        264MB         69.3MB        
shopkart-api:1.1       33417eb02681        240MB         58.4MB        
shopkart-api:1.2       5eaaae04d1db        153MB         37.2MB        
shopkart-api:compose   aa2dccbf1b49        153MB         37.2MB        
shopkart-api:fat       9280964f80c8        1.8GB          470MB        
shopkart-api:slim      4fcb7511afdd        241MB         58.4MB        
shopkart-api:small     812ff33a289c        141MB         33.7MB        
$ docker history shopkart-api:small --format 'table {{.CreatedBy}}\t{{.Size}}' | head -n 6
CREATED BY                                      SIZE
CMD ["uvicorn" "shopkart_api.main:app" "--ho…   0B
COPY . . # buildkit                             172kB
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
429607a5043f15f102972e2f5f54e4eec33946d414f810d537110a626101d989
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

real	0m20.657s
user	0m0.140s
sys	0m0.083s
$ time docker build -f labs/slim-image/done/Dockerfile -t shopkart-api:small app/api 2>&1 | grep -c 'Using cached'
34

real	0m17.312s
user	0m0.148s
sys	0m0.080s
$ git checkout -- app/api/requirements.txt
$ docker buildx du | tail -n 3
Private:	631.5MB
Reclaimable:	3.04GB
Total:		3.04GB
```

