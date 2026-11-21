# Containerize the ShopKart API (Dockerfile, two parts): tested run

Recorded on 2026-11-21 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings and sizes will differ.

## Part 1. The first Dockerfile

```console
$ cat labs/dockerfile/done/part1/Dockerfile
# Part 1: the ShopKart API in a container. Simple, and it works.
FROM python:3.12.16-slim-trixie
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["uvicorn", "shopkart_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
$ docker build -f labs/dockerfile/done/part1/Dockerfile -t shopkart-api:1.0 app/api
[... 106 earlier lines of output cut ...]
#8 10.16 Downloading click-8.5.1-py3-none-any.whl (126 kB)
#8 10.30 Downloading h11-0.16.0-py3-none-any.whl (37 kB)
#8 10.44 Downloading opentelemetry_api-1.45.2-py3-none-any.whl (60 kB)
#8 10.57 Downloading pydantic-2.14.4-py3-none-any.whl (494 kB)
#8 10.72 Downloading pydantic_core-2.50.5-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl (2.3 MB)
#8 10.78    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 2.3/2.3 MB 37.1 MB/s eta 0:00:00
#8 10.90 Downloading starlette-1.10.0-py3-none-any.whl (80 kB)
#8 11.04 Downloading typing_extensions-4.16.0-py3-none-any.whl (45 kB)
#8 11.17 Downloading typing_inspection-0.4.5-py3-none-any.whl (14 kB)
#8 11.30 Downloading annotated_types-0.8.0-py3-none-any.whl (13 kB)
#8 11.44 Downloading idna-3.20-py3-none-any.whl (69 kB)
#8 11.52 Installing collected packages: typing-extensions, redis, psycopg-binary, idna, h11, click, annotated-types, annotated-doc, uvicorn, typing-inspection, pydantic-core, psycopg, opentelemetry-api, anyio, starlette, pydantic, fastapi
#8 13.31 Successfully installed annotated-doc-0.0.7 annotated-types-0.8.0 anyio-4.16.0 click-8.5.1 fastapi-0.165.0 h11-0.16.0 idna-3.20 opentelemetry-api-1.45.2 psycopg-3.3.9 psycopg-binary-3.3.9 pydantic-2.14.4 pydantic-core-2.50.5 redis-8.1.0 starlette-1.10.0 typing-extensions-4.16.0 typing-inspection-0.4.5 uvicorn-0.54.0
#8 13.31 WARNING: Running pip as the 'root' user can result in broken permissions and conflicting behaviour with the system package manager, possibly rendering your system unusable. It is recommended to use a virtual environment instead: https://pip.pypa.io/warnings/venv. Use the --root-user-action option if you know what you are doing and want to suppress this warning.
#8 13.76 
#8 13.76 [notice] A new release of pip is available: 25.0.1 -> 26.3
#8 13.76 [notice] To update, run: pip install --upgrade pip
#8 DONE 14.9s

#9 exporting to image
#9 exporting layers
#9 exporting layers 2.4s done
#9 exporting manifest sha256:3e7d8b3c1017586b038f0308aecf7603f16c3fe2b04bcefda3dda6537d483f12 0.0s done
#9 exporting config sha256:201f5912a64e5d54ed94f57ee92958ed03bb3d1895eb29744762c33707cd2a4d 0.0s done
#9 exporting attestation manifest sha256:781345487d53c3d046cd1d40212797c0c7131d2fd8e8f96a5483337664ff7d6a 0.1s done
#9 exporting manifest list sha256:8b0f52fd3953a1214fd305b5cd67d6797bce2b7923a8ec897d12dbd30061e39e 0.0s done
#9 naming to docker.io/library/shopkart-api:1.0 done
#9 unpacking to docker.io/library/shopkart-api:1.0
#9 unpacking to docker.io/library/shopkart-api:1.0 1.7s done
#9 DONE 4.4s
$ docker images shopkart-api
IMAGE              ID             DISK USAGE   CONTENT SIZE   EXTRA
shopkart-api:1.0   8b0f52fd3953        264MB         69.3MB        
$ docker run -d --name api -p 8000:8000 shopkart-api:1.0
9a12314cfce9ea0fa6edecca821ed0f64c3149c4e9b42f99bcde3beacb917149
$ curl -s localhost:8000/health; echo
{"status":"ok","db":"ok","cart":"ok"}
$ curl -s localhost:8000/api/products | head -c 160; echo
[{"id":1,"name":"Cotton Kurta","category":"Clothing","price_inr":899,"stock":40},{"id":2,"name":"Running Shoes","category":"Footwear","price_inr":2499,"stock":2
$ docker logs api
INFO shopkart: ShopKart dev starting (env=local, db=sqlite)
INFO:     Started server process [1]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     172.18.0.1:55254 - "GET /health HTTP/1.1" 200 OK
INFO:     172.18.0.1:55258 - "GET /api/products HTTP/1.1" 200 OK
$ docker history shopkart-api:1.0
IMAGE          CREATED          CREATED BY                                      SIZE      COMMENT
8b0f52fd3953   12 seconds ago   CMD ["uvicorn" "shopkart_api.main:app" "--ho…   0B        buildkit.dockerfile.v0
<missing>      12 seconds ago   RUN /bin/sh -c pip install -r requirements.t…   60.3MB    buildkit.dockerfile.v0
<missing>      27 seconds ago   COPY . . # buildkit                             172kB     buildkit.dockerfile.v0
<missing>      27 seconds ago   WORKDIR /app                                    8.19kB    buildkit.dockerfile.v0
<missing>      2 weeks ago      CMD ["python3"]                                 0B        buildkit.dockerfile.v0
<missing>      2 weeks ago      RUN /bin/sh -c set -eux;  for src in idle3 p…   16.4kB    buildkit.dockerfile.v0
<missing>      2 weeks ago      RUN /bin/sh -c set -eux;   savedAptMark="$(a…   41.4MB    buildkit.dockerfile.v0
<missing>      2 weeks ago      ENV PYTHON_SHA256=b5796915dc45ff745cfb4e990a…   0B        buildkit.dockerfile.v0
<missing>      2 weeks ago      ENV PYTHON_VERSION=3.12.16                      0B        buildkit.dockerfile.v0
<missing>      2 weeks ago      ENV GPG_KEY=7169605F62C751356D054A26A821E680…   0B        buildkit.dockerfile.v0
<missing>      2 weeks ago      RUN /bin/sh -c set -eux;  apt-get update;  a…   4.93MB    buildkit.dockerfile.v0
<missing>      2 weeks ago      ENV LANG=C.UTF-8                                0B        buildkit.dockerfile.v0
<missing>      2 weeks ago      ENV PATH=/usr/local/bin:/usr/local/sbin:/usr…   0B        buildkit.dockerfile.v0
<missing>      2 weeks ago      # debian.sh --arch 'amd64' out/ 'trixie' '@1…   87.7MB    debuerreotype 0.17
$ docker rm -f api
api
```

## Part 2. A one-line code change re-runs pip (slow)

```console
$ echo '# a small code change' >> app/api/shopkart_api/main.py
$ time docker build -f labs/dockerfile/done/part1/Dockerfile -t shopkart-api:1.0 app/api
[... 84 earlier lines of output cut ...]
#8 12.98 WARNING: Running pip as the 'root' user can result in broken permissions and conflicting behaviour with the system package manager, possibly rendering your system unusable. It is recommended to use a virtual environment instead: https://pip.pypa.io/warnings/venv. Use the --root-user-action option if you know what you are doing and want to suppress this warning.
#8 13.44 
#8 13.44 [notice] A new release of pip is available: 25.0.1 -> 26.3
#8 13.44 [notice] To update, run: pip install --upgrade pip
#8 DONE 14.2s

#9 exporting to image
#9 exporting layers
#9 exporting layers 2.3s done
#9 exporting manifest sha256:0c61d701e487f232fdd1e07af1c39e03121609789a111c98e42ae1008c594146 0.0s done
#9 exporting config sha256:a2bf3f42da723abb4b6333b207052cca3841bc46abf128fc48f0a699f276d6c4 0.0s done
#9 exporting attestation manifest sha256:76abbf5886b3fd2cbf3c01ec40d2181a1ab2e00862083a86434ef049ef0f986a
#9 exporting attestation manifest sha256:76abbf5886b3fd2cbf3c01ec40d2181a1ab2e00862083a86434ef049ef0f986a 0.0s done
#9 exporting manifest list sha256:62aaa0e3d372b9efda8179243e1fe4a64c2d68f672eda9d1101a33fa2e398b5f 0.0s done
#9 naming to docker.io/library/shopkart-api:1.0 done
#9 unpacking to docker.io/library/shopkart-api:1.0
#9 unpacking to docker.io/library/shopkart-api:1.0 0.6s done
#9 DONE 3.0s

real	0m18.522s
user	0m0.117s
sys	0m0.083s
```

## Part 2. Dependencies first, .dockerignore, version, health check

```console
$ cat labs/dockerfile/done/part2/Dockerfile
# Part 2: fast rebuilds, a version label and a health check.
FROM python:3.12.16-slim-trixie

# Build-time input (ARG) -> kept at run time (ENV)
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Dependencies first: this layer is reused until requirements.txt changes
COPY requirements.txt .
RUN pip install -r requirements.txt

# Then the code, which changes all the time
COPY . .

EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

# ENTRYPOINT = the program, CMD = default arguments you can override at `docker run`
ENTRYPOINT ["uvicorn", "shopkart_api.main:app"]
CMD ["--host", "0.0.0.0", "--port", "8000"]
$ cat labs/dockerfile/done/part2/Dockerfile.dockerignore
# Only for done/part2/Dockerfile (Docker reads <Dockerfile>.dockerignore next to the Dockerfile)
__pycache__/
*.pyc
.pytest_cache/
tests/
*.db
.env
.env.*
Dockerfile*
$ docker build -f labs/dockerfile/done/part2/Dockerfile --build-arg APP_VERSION=1.1 -t shopkart-api:1.1 app/api
[... 74 earlier lines of output cut ...]
#7 11.02 Downloading typing_extensions-4.16.0-py3-none-any.whl (45 kB)
#7 11.14 Downloading typing_inspection-0.4.5-py3-none-any.whl (14 kB)
#7 11.26 Downloading annotated_types-0.8.0-py3-none-any.whl (13 kB)
#7 11.39 Downloading idna-3.20-py3-none-any.whl (69 kB)
#7 11.45 Installing collected packages: typing-extensions, redis, psycopg-binary, idna, h11, click, annotated-types, annotated-doc, uvicorn, typing-inspection, pydantic-core, psycopg, opentelemetry-api, anyio, starlette, pydantic, fastapi
#7 13.23 Successfully installed annotated-doc-0.0.7 annotated-types-0.8.0 anyio-4.16.0 click-8.5.1 fastapi-0.165.0 h11-0.16.0 idna-3.20 opentelemetry-api-1.45.2 psycopg-3.3.9 psycopg-binary-3.3.9 pydantic-2.14.4 pydantic-core-2.50.5 redis-8.1.0 starlette-1.10.0 typing-extensions-4.16.0 typing-inspection-0.4.5 uvicorn-0.54.0
#7 13.23 WARNING: Running pip as the 'root' user can result in broken permissions and conflicting behaviour with the system package manager, possibly rendering your system unusable. It is recommended to use a virtual environment instead: https://pip.pypa.io/warnings/venv. Use the --root-user-action option if you know what you are doing and want to suppress this warning.
#7 DONE 13.9s

#8 [5/5] COPY . .
#8 DONE 0.2s

#9 exporting to image
#9 exporting layers
#9 exporting layers 1.9s done
#9 exporting manifest sha256:c75a69b22e72b2bec680f57f7e506690c95a45728a12c2156826af80d773598f
#9 exporting manifest sha256:c75a69b22e72b2bec680f57f7e506690c95a45728a12c2156826af80d773598f 0.0s done
#9 exporting config sha256:1579c3da8ed60fde6c15eec1ca27fca0557de29a9c6e1b8cd8987b65035e52bd 0.0s done
#9 exporting attestation manifest sha256:54fb07e6b1c4ba867d049fafdb9b78635edbdd8ecb17b660860c83dcd826a4ab
#9 exporting attestation manifest sha256:54fb07e6b1c4ba867d049fafdb9b78635edbdd8ecb17b660860c83dcd826a4ab 0.0s done
#9 exporting manifest list sha256:8523b71280ce33c9b91c3ba185f471d3e05c4523e6c34e73fb6516dbd802c710 0.0s done
#9 naming to docker.io/library/shopkart-api:1.1 done
#9 unpacking to docker.io/library/shopkart-api:1.1
#9 unpacking to docker.io/library/shopkart-api:1.1 0.6s done
#9 DONE 2.7s
```

Change the code again and rebuild: the pip layer comes from the cache.

```console
$ echo '# another small change' >> app/api/shopkart_api/main.py
$ time docker build -f labs/dockerfile/done/part2/Dockerfile --build-arg APP_VERSION=1.1 -t shopkart-api:1.1 app/api
[... 23 earlier lines of output cut ...]
#7 [4/5] RUN pip install -r requirements.txt
#7 CACHED

#8 [5/5] COPY . .
#8 DONE 0.6s

#9 exporting to image
#9 exporting layers
#9 exporting layers 0.2s done
#9 exporting manifest sha256:65c43806ebdd9f38e012f477d9c2a833ccda1140996b4a52250d63ca22b826eb
#9 exporting manifest sha256:65c43806ebdd9f38e012f477d9c2a833ccda1140996b4a52250d63ca22b826eb 0.0s done
#9 exporting config sha256:3fa49560f85718b59e847f4bc72d90b0a96940a6b368b65863b33f897118ad98 0.0s done
#9 exporting attestation manifest sha256:82a5ba690a8d81c3489ceca69309dc831651fdf757ff52f01265b4b3d723a8b9
#9 exporting attestation manifest sha256:82a5ba690a8d81c3489ceca69309dc831651fdf757ff52f01265b4b3d723a8b9 0.0s done
#9 exporting manifest list sha256:33417eb02681a1d5c909df4b494712652e798b82fb71d54b325f4f09105b4d59 0.0s done
#9 naming to docker.io/library/shopkart-api:1.1 done
#9 unpacking to docker.io/library/shopkart-api:1.1 0.0s done
#9 DONE 0.4s

real	0m1.686s
user	0m0.091s
sys	0m0.065s
$ git checkout -- app/api/shopkart_api/main.py
```

## Part 2. Run it: healthy, and it knows its version

```console
$ docker run -d --name api -p 8000:8000 shopkart-api:1.1
ebc95d609112905d877a4196d1cd1e9ea1a49e386443855f520f87cbdf2ecbcf
$ docker ps --filter name=api
CONTAINER ID   IMAGE              COMMAND                  CREATED         STATUS                            PORTS                                         NAMES
ebc95d609112   shopkart-api:1.1   "uvicorn shopkart_ap…"   3 seconds ago   Up 2 seconds (health: starting)   0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp   api
$ docker ps --filter name=api
CONTAINER ID   IMAGE              COMMAND                  CREATED          STATUS                    PORTS                                         NAMES
ebc95d609112   shopkart-api:1.1   "uvicorn shopkart_ap…"   15 seconds ago   Up 14 seconds (healthy)   0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp   api
$ docker inspect api --format '{{.State.Health.Status}} {{(index .State.Health.Log 0).ExitCode}}'
healthy 0
$ curl -s localhost:8000/api/info; echo
{"app":"shopkart-api","version":"1.1","env":"local","db":"sqlite","banner":"","host":"ebc95d609112"}
```

## Part 2. ENTRYPOINT + CMD: override only the arguments

```console
$ docker run -d --name api-9000 -p 9000:9000 shopkart-api:1.1 --host 0.0.0.0 --port 9000 --log-level warning
8f93f337e613f1911242f4a87d9c110988d12fe764409fce30abfa2d1191596b
$ curl -s localhost:9000/health; echo
{"status":"ok","db":"ok","cart":"ok"}
$ docker inspect shopkart-api:1.1 --format 'ENTRYPOINT={{json .Config.Entrypoint}} CMD={{json .Config.Cmd}}'
ENTRYPOINT=["uvicorn","shopkart_api.main:app"] CMD=["--host","0.0.0.0","--port","8000"]
```

## Clean up

```console
$ docker rm -f api api-9000
api
api-9000
```

