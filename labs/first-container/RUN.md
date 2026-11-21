# Your first container: tested run

Recorded on 2026-11-21 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings and sizes will differ.

## Before containers: ShopKart on Python

Terminal 1 (left running, then stopped with Ctrl+C):

```console
$ timeout -s INT 28 ./scripts/run-local.sh
INFO shopkart: ShopKart dev starting (env=local, db=sqlite)
INFO:     Started server process [41441]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     127.0.0.1:45526 - "GET /health HTTP/1.1" 200 OK
INFO:     127.0.0.1:45534 - "GET /api/products HTTP/1.1" 200 OK
INFO:     Shutting down
INFO:     Waiting for application shutdown.
INFO:     Application shutdown complete.
INFO:     Finished server process [41441]
```

Terminal 2, while it runs:

```console
$ curl -s localhost:8000/health
{"status":"ok","db":"ok","cart":"ok"}
$ curl -s localhost:8000/api/products | head -c 160
[{"id":1,"name":"Cotton Kurta","category":"Clothing","price_inr":899,"stock":40},{"id":2,"name":"Running Shoes","category":"Footwear","price_inr":2499,"stock":2
```

## Check Docker

```console
$ docker version
Client: Docker Engine - Community
 Version:           29.10.0
 API version:       1.57
 Go version:        go1.27.4
 Git commit:        fdd4b8e
 Built:             Mon Nov 16 11:00:37 2026
 OS/Arch:           linux/amd64
 Context:           default

Server: Docker Engine - Community
 Engine:
  Version:          29.10.0
  API version:      1.57 (minimum version 1.40)
  Go version:       go1.27.4
  Git commit:       06db173
  Built:            Mon Nov 16 11:00:54 2026
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          v2.4.2
  GitCommit:        b7a25261e029d68978bbf290df0a62fc819b3c51
 runc:
  Version:          1.5.3
  GitCommit:        v1.5.3-0-g46365c62
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0
```

## Hello, world

```console
$ docker run hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
4f55086f7dd0: Pulling fs layer
4f55086f7dd0: Download complete
4f55086f7dd0: Pull complete
d5e71e642bf5: Download complete
Digest: sha256:1e4c05b897a751332ce85c7e9449da2d93514ea2dea6dbb0e2753c9e949b2bfa
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/

```

## Run a web server

```console
$ docker run -d --name web -p 8080:80 nginx:1.30.7-alpine
Unable to find image 'nginx:1.30.7-alpine' locally
1.30.7-alpine: Pulling from library/nginx
893b1907c4dc: Pulling fs layer
c188e096e949: Pulling fs layer
881fc932939e: Pulling fs layer
1197128e240d: Pulling fs layer
2631dab31190: Pulling fs layer
cc0947b1a774: Pulling fs layer
4f56c5508527: Pulling fs layer
61e5576dbd35: Pulling fs layer
c188e096e949: Download complete
893b1907c4dc: Download complete
881fc932939e: Download complete
1197128e240d: Download complete
2631dab31190: Download complete
cc0947b1a774: Download complete
61e5576dbd35: Download complete
4f56c5508527: Download complete
881fc932939e: Pull complete
359761868b5a: Download complete
1197128e240d: Pull complete
cd2bd754171e: Download complete
c188e096e949: Pull complete
2631dab31190: Pull complete
cc0947b1a774: Pull complete
4f56c5508527: Pull complete
61e5576dbd35: Pull complete
893b1907c4dc: Pull complete
Digest: sha256:caf4e1e032a20f9c3c5e28fc7f25ffd768ad8677b4975c54193075997b3a97e3
Status: Downloaded newer image for nginx:1.30.7-alpine
0b85be73170dd48a47ea6908d6b8198f3c6f8d01d500615f30c42a99fbfb612b
$ docker ps
CONTAINER ID   IMAGE                 COMMAND                  CREATED         STATUS         PORTS                                     NAMES
0b85be73170d   nginx:1.30.7-alpine   "/docker-entrypoint.…"   3 seconds ago   Up 2 seconds   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   web
$ curl -s localhost:8080 | head -n 4
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```

## Logs, stop, remove

```console
$ docker logs web
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
172.18.0.1 - - [21/Nov/2026:20:29:58 +0000] "GET / HTTP/1.1" 200 896 "-" "curl/7.88.1" "-"
2026/11/21 20:29:56 [notice] 1#1: using the "epoll" event method
2026/11/21 20:29:56 [notice] 1#1: nginx/1.30.7
2026/11/21 20:29:56 [notice] 1#1: built by gcc 15.2.0 (Alpine 15.2.0) 
2026/11/21 20:29:56 [notice] 1#1: OS: Linux 7.0.0-1017-azure
2026/11/21 20:29:56 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1024:524288
2026/11/21 20:29:56 [notice] 1#1: start worker processes
2026/11/21 20:29:56 [notice] 1#1: start worker process 31
2026/11/21 20:29:56 [notice] 1#1: start worker process 32
$ docker stop web
web
$ docker rm web
web
$ docker ps -a
CONTAINER ID   IMAGE         COMMAND    CREATED         STATUS                     PORTS     NAMES
b302c35f29a4   hello-world   "/hello"   9 seconds ago   Exited (0) 7 seconds ago             kind_wozniak
```

