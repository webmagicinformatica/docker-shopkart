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
[... 108 earlier lines of output cut ...]
#8 11.08 Downloading opentelemetry_api-1.45.2-py3-none-any.whl (60 kB)
#8 11.22 Downloading pydantic-2.14.4-py3-none-any.whl (494 kB)
#8 11.38 Downloading pydantic_core-2.50.5-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl (2.3 MB)
#8 11.44    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 2.3/2.3 MB 35.3 MB/s eta 0:00:00
#8 11.56 Downloading starlette-1.10.0-py3-none-any.whl (80 kB)
#8 11.71 Downloading typing_extensions-4.16.0-py3-none-any.whl (45 kB)
#8 11.85 Downloading typing_inspection-0.4.5-py3-none-any.whl (14 kB)
#8 11.99 Downloading annotated_types-0.8.0-py3-none-any.whl (13 kB)
#8 12.13 Downloading idna-3.20-py3-none-any.whl (69 kB)
#8 12.22 Installing collected packages: typing-extensions, redis, psycopg-binary, idna, h11, click, annotated-types, annotated-doc, uvicorn, typing-inspection, pydantic-core, psycopg, opentelemetry-api, anyio, starlette, pydantic, fastapi
#8 14.25 Successfully installed annotated-doc-0.0.7 annotated-types-0.8.0 anyio-4.16.0 click-8.5.1 fastapi-0.165.0 h11-0.16.0 idna-3.20 opentelemetry-api-1.45.2 psycopg-3.3.9 psycopg-binary-3.3.9 pydantic-2.14.4 pydantic-core-2.50.5 redis-8.1.0 starlette-1.10.0 typing-extensions-4.16.0 typing-inspection-0.4.5 uvicorn-0.54.0
#8 14.25 WARNING: Running pip as the 'root' user can result in broken permissions and conflicting behaviour with the system package manager, possibly rendering your system unusable. It is recommended to use a virtual environment instead: https://pip.pypa.io/warnings/venv. Use the --root-user-action option if you know what you are doing and want to suppress this warning.
#8 14.77 
#8 14.77 [notice] A new release of pip is available: 25.0.1 -> 26.3
#8 14.77 [notice] To update, run: pip install --upgrade pip
#8 DONE 16.2s

#9 exporting to image
#9 exporting layers
#9 exporting layers 2.7s done
#9 exporting manifest sha256:0be57bfa4e92afc2796edf8fed6e273c9b53d4b849e35fbd6270109fa8180eb2
#9 exporting manifest sha256:0be57bfa4e92afc2796edf8fed6e273c9b53d4b849e35fbd6270109fa8180eb2 0.0s done
#9 exporting config sha256:6a6ef280d5cc08d67050711fcb7405bc6166e218b3b3b5d4095ba6cc70743ca0 0.0s done
#9 exporting attestation manifest sha256:f295a78d5f221ccabd34dcd8bd1e14ceed1aa8ca28f611d07acb33145f2625e0
#9 exporting attestation manifest sha256:f295a78d5f221ccabd34dcd8bd1e14ceed1aa8ca28f611d07acb33145f2625e0 0.1s done
#9 exporting manifest list sha256:be8fdc3e4243282a5a682579038fb3854db2d583e5c8387efafc536589123069 0.0s done
#9 naming to docker.io/library/shopkart-api:1.0 done
#9 unpacking to docker.io/library/shopkart-api:1.0
#9 unpacking to docker.io/library/shopkart-api:1.0 1.8s done
#9 DONE 4.8s
$ docker images shopkart-api
IMAGE              ID             DISK USAGE   CONTENT SIZE   EXTRA
shopkart-api:1.0   be8fdc3e4243        264MB         69.3MB        
$ docker run -d --name api -p 8000:8000 shopkart-api:1.0
509cfb010eaa6df6d28cfcee5bba1f62c28ace4275947339a8c971a866f3ec06
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
INFO:     172.18.0.1:55928 - "GET /health HTTP/1.1" 200 OK
INFO:     172.18.0.1:55930 - "GET /api/products HTTP/1.1" 200 OK
$ docker history shopkart-api:1.0
IMAGE          CREATED          CREATED BY                                      SIZE      COMMENT
be8fdc3e4243   13 seconds ago   CMD ["uvicorn" "shopkart_api.main:app" "--ho…   0B        buildkit.dockerfile.v0
<missing>      13 seconds ago   RUN /bin/sh -c pip install -r requirements.t…   60.3MB    buildkit.dockerfile.v0
<missing>      29 seconds ago   COPY . . # buildkit                             152kB     buildkit.dockerfile.v0
<missing>      30 seconds ago   WORKDIR /app                                    8.19kB    buildkit.dockerfile.v0
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
[... 85 earlier lines of output cut ...]
#8 14.29 
#8 14.29 [notice] A new release of pip is available: 25.0.1 -> 26.3
#8 14.29 [notice] To update, run: pip install --upgrade pip
#8 DONE 15.8s

#9 exporting to image
#9 exporting layers
#9 exporting layers 2.6s done
#9 exporting manifest sha256:5c743b3ae979545706ab1d9c02d564b4e5b7d8be9fa7b219dd7464511508ca1b
#9 exporting manifest sha256:5c743b3ae979545706ab1d9c02d564b4e5b7d8be9fa7b219dd7464511508ca1b 0.0s done
#9 exporting config sha256:f1fbb93968ddac1776ffacc52ca1051c5ed87b62da8167dc4f09ee1238cec4d4 0.0s done
#9 exporting attestation manifest sha256:97987dba87722af311d3695bbeb1272fc674282c51f941affe7caef7126ef99c
#9 exporting attestation manifest sha256:97987dba87722af311d3695bbeb1272fc674282c51f941affe7caef7126ef99c 0.0s done
#9 exporting manifest list sha256:140a334004c344a5c90b500763013df7ff60efb05d7823e20a9ed644bfcab050 0.0s done
#9 naming to docker.io/library/shopkart-api:1.0 done
#9 unpacking to docker.io/library/shopkart-api:1.0
#9 unpacking to docker.io/library/shopkart-api:1.0 0.6s done
#9 DONE 3.5s

real	0m20.846s
user	0m0.134s
sys	0m0.078s
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
#7 9.904 Downloading typing_extensions-4.16.0-py3-none-any.whl (45 kB)
#7 10.01 Downloading typing_inspection-0.4.5-py3-none-any.whl (14 kB)
#7 10.11 Downloading annotated_types-0.8.0-py3-none-any.whl (13 kB)
#7 10.20 Downloading idna-3.20-py3-none-any.whl (69 kB)
#7 10.27 Installing collected packages: typing-extensions, redis, psycopg-binary, idna, h11, click, annotated-types, annotated-doc, uvicorn, typing-inspection, pydantic-core, psycopg, opentelemetry-api, anyio, starlette, pydantic, fastapi
#7 12.35 Successfully installed annotated-doc-0.0.7 annotated-types-0.8.0 anyio-4.16.0 click-8.5.1 fastapi-0.165.0 h11-0.16.0 idna-3.20 opentelemetry-api-1.45.2 psycopg-3.3.9 psycopg-binary-3.3.9 pydantic-2.14.4 pydantic-core-2.50.5 redis-8.1.0 starlette-1.10.0 typing-extensions-4.16.0 typing-inspection-0.4.5 uvicorn-0.54.0
#7 12.35 WARNING: Running pip as the 'root' user can result in broken permissions and conflicting behaviour with the system package manager, possibly rendering your system unusable. It is recommended to use a virtual environment instead: https://pip.pypa.io/warnings/venv. Use the --root-user-action option if you know what you are doing and want to suppress this warning.
#7 DONE 13.5s

#8 [5/5] COPY . .
#8 DONE 0.5s

#9 exporting to image
#9 exporting layers
#9 exporting layers 2.2s done
#9 exporting manifest sha256:6bc8d325a252caa55e45361c23dabff32272a09d5b22e1ea42bc9f68d9f8c738
#9 exporting manifest sha256:6bc8d325a252caa55e45361c23dabff32272a09d5b22e1ea42bc9f68d9f8c738 0.0s done
#9 exporting config sha256:53bb631932354c992bef15aab372de2c3c749f431aebe038e09206161f9f1087 0.0s done
#9 exporting attestation manifest sha256:728ec771bf9bb32b0de5077cc8b8b2c11a0c7db3e20fe0e8f3fd21f2bdbc7944
#9 exporting attestation manifest sha256:728ec771bf9bb32b0de5077cc8b8b2c11a0c7db3e20fe0e8f3fd21f2bdbc7944 0.0s done
#9 exporting manifest list sha256:6aec6547d5ed4ddd0234a5ebe32b70b215e9407b2ade8be854ac58de3c62fd4a 0.0s done
#9 naming to docker.io/library/shopkart-api:1.1 done
#9 unpacking to docker.io/library/shopkart-api:1.1
#9 unpacking to docker.io/library/shopkart-api:1.1 0.5s done
#9 DONE 2.9s
```

Change the code again and rebuild: the pip layer comes from the cache.

```console
$ echo '# another small change' >> app/api/shopkart_api/main.py
$ time docker build -f labs/dockerfile/done/part2/Dockerfile --build-arg APP_VERSION=1.1 -t shopkart-api:1.1 app/api
[... 24 earlier lines of output cut ...]
#7 CACHED

#8 [5/5] COPY . .
#8 DONE 0.8s

#9 exporting to image
#9 exporting layers
#9 exporting layers 0.2s done
#9 exporting manifest sha256:ddfd1b8efd74fa9fd931bd25cbacef741b27c99a02a9ccc92058f4c24c096e7a
#9 exporting manifest sha256:ddfd1b8efd74fa9fd931bd25cbacef741b27c99a02a9ccc92058f4c24c096e7a 0.0s done
#9 exporting config sha256:779b216d3f66fbec1de99953d5cc8d4bfe710c7886e5dde23ec81936915b35f7 0.0s done
#9 exporting attestation manifest sha256:7406d34907421452594c1e0994c3946d0e5a167f429e888c187e38847b1ce261
#9 exporting attestation manifest sha256:7406d34907421452594c1e0994c3946d0e5a167f429e888c187e38847b1ce261 0.1s done
#9 exporting manifest list sha256:35a53779dedde1863304075fbb3f85ee65e650174622a3500917dfafbbd27ccb 0.0s done
#9 naming to docker.io/library/shopkart-api:1.1
#9 naming to docker.io/library/shopkart-api:1.1 done
#9 unpacking to docker.io/library/shopkart-api:1.1 0.1s done
#9 DONE 0.5s

real	0m2.067s
user	0m0.107s
sys	0m0.062s
$ git checkout -- app/api/shopkart_api/main.py
```

## Part 2. Run it: healthy, and it knows its version

```console
$ docker run -d --name api -p 8000:8000 shopkart-api:1.1
a4f6dfd2613d5ef3d68a9ef0ca75374e6cad6ae35e955a2be00397fc1d33feda
$ docker ps --filter name=api
CONTAINER ID   IMAGE              COMMAND                  CREATED         STATUS                            PORTS                                         NAMES
a4f6dfd2613d   shopkart-api:1.1   "uvicorn shopkart_ap…"   3 seconds ago   Up 2 seconds (health: starting)   0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp   api
$ docker ps --filter name=api
CONTAINER ID   IMAGE              COMMAND                  CREATED          STATUS                    PORTS                                         NAMES
a4f6dfd2613d   shopkart-api:1.1   "uvicorn shopkart_ap…"   16 seconds ago   Up 14 seconds (healthy)   0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp   api
$ docker inspect api --format '{{.State.Health.Status}} {{(index .State.Health.Log 0).ExitCode}}'
healthy 0
$ curl -s localhost:8000/api/info; echo
{"app":"shopkart-api","version":"1.1","env":"local","db":"sqlite","banner":"","host":"a4f6dfd2613d"}
```

## Part 2. ENTRYPOINT + CMD: override only the arguments

```console
$ docker run -d --name api-9000 -p 9000:9000 shopkart-api:1.1 --host 0.0.0.0 --port 9000 --log-level warning
71a4347b065b6d8eb7fdc1077d575326e562859e507bfa9d16ba90c40d47cddb
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

