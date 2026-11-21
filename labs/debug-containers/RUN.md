# Debug three broken containers: tested run

Recorded on 2026-11-21 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings and sizes will differ.

The postgres and python images were pulled before this run, so the pull output is not shown.

## 1. Break things

```console
$ ./labs/debug-containers/start/break.sh
4d2d98483e4ff2bc2a9d9294601bfd625c84b03fb571f6901de8cfa0a74bce2b
ecf422faf46e76b6124da5edc3750205d1268b84e0f9f878a898ee445a0440d7
f576d0cacd76e2d158f24fbd3d88c7909b6f15b61df7d1afc718bdbca9400b9a
Three containers started. Now find out what's wrong: docker ps -a
$ docker ps -a --filter name=sk-
CONTAINER ID   IMAGE                       COMMAND                  CREATED          STATUS                        PORTS                                                 NAMES
f576d0cacd76   python:3.12.16-alpine3.24   "python -c 'print('L…"   11 seconds ago   Exited (137) 10 seconds ago                                                         sk-warmup
ecf422faf46e   nginx:1.30.7-alpine         "/docker-entrypoint.…"   12 seconds ago   Up 11 seconds                 80/tcp, 0.0.0.0:8081->8080/tcp, [::]:8081->8080/tcp   sk-web
4d2d98483e4f   postgres:17.12-alpine       "docker-entrypoint.s…"   15 seconds ago   Exited (1) 6 seconds ago                                                            sk-db
```

## 2. The crash loop: sk-db

```console
$ docker ps -a --filter name=sk-db --format '{{.Names}}: {{.Status}}'
sk-db: Exited (1) 6 seconds ago
$ docker inspect sk-db --format 'restarts={{.RestartCount}} exit={{.State.ExitCode}} policy={{.HostConfig.RestartPolicy.Name}}'
restarts=5 exit=1 policy=on-failure
$ docker logs sk-db
Error: Database is uninitialized and superuser password is not specified.
       You must specify POSTGRES_PASSWORD to a non-empty value for the
       superuser. For example, "-e POSTGRES_PASSWORD=password" on "docker run".

       You may also use "POSTGRES_HOST_AUTH_METHOD=trust" to allow all
       connections without a password. This is *not* recommended.

       See PostgreSQL documentation about "trust":
       https://www.postgresql.org/docs/current/auth-trust.html
Error: Database is uninitialized and superuser password is not specified.
       You must specify POSTGRES_PASSWORD to a non-empty value for the
       superuser. For example, "-e POSTGRES_PASSWORD=password" on "docker run".

       You may also use "POSTGRES_HOST_AUTH_METHOD=trust" to allow all
       connections without a password. This is *not* recommended.

       See PostgreSQL documentation about "trust":
       https://www.postgresql.org/docs/current/auth-trust.html
Error: Database is uninitialized and superuser password is not specified.
       You must specify POSTGRES_PASSWORD to a non-empty value for the
       superuser. For example, "-e POSTGRES_PASSWORD=password" on "docker run".

       You may also use "POSTGRES_HOST_AUTH_METHOD=trust" to allow all
       connections without a password. This is *not* recommended.

       See PostgreSQL documentation about "trust":
       https://www.postgresql.org/docs/current/auth-trust.html
Error: Database is uninitialized and superuser password is not specified.
       You must specify POSTGRES_PASSWORD to a non-empty value for the
       superuser. For example, "-e POSTGRES_PASSWORD=password" on "docker run".

       You may also use "POSTGRES_HOST_AUTH_METHOD=trust" to allow all
       connections without a password. This is *not* recommended.

       See PostgreSQL documentation about "trust":
       https://www.postgresql.org/docs/current/auth-trust.html
Error: Database is uninitialized and superuser password is not specified.
       You must specify POSTGRES_PASSWORD to a non-empty value for the
       superuser. For example, "-e POSTGRES_PASSWORD=password" on "docker run".

       You may also use "POSTGRES_HOST_AUTH_METHOD=trust" to allow all
       connections without a password. This is *not* recommended.

       See PostgreSQL documentation about "trust":
       https://www.postgresql.org/docs/current/auth-trust.html
Error: Database is uninitialized and superuser password is not specified.
       You must specify POSTGRES_PASSWORD to a non-empty value for the
       superuser. For example, "-e POSTGRES_PASSWORD=password" on "docker run".

       You may also use "POSTGRES_HOST_AUTH_METHOD=trust" to allow all
       connections without a password. This is *not* recommended.

       See PostgreSQL documentation about "trust":
       https://www.postgresql.org/docs/current/auth-trust.html
```

## 3. The wrong port: sk-web

```console
$ docker ps --filter name=sk-web --format '{{.Names}}: {{.Status}}  {{.Ports}}'
sk-web: Up 11 seconds  80/tcp, 0.0.0.0:8081->8080/tcp, [::]:8081->8080/tcp
$ curl -sS localhost:8081
curl: (56) Recv failure: Connection reset by peer
$ docker exec sk-web netstat -tln
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      
tcp        0      0 :::80                   :::*                    LISTEN      
```

## 4. Out of memory: sk-warmup

```console
$ docker ps -a --filter name=sk-warmup --format '{{.Names}}: {{.Status}}'
sk-warmup: Exited (137) 10 seconds ago
$ docker logs sk-warmup
Loading 150 MB of cart data...
$ docker inspect sk-warmup --format 'exit={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}} limit={{.HostConfig.Memory}}'
exit=137 OOMKilled=true limit=67108864
```

## 5. Apply the fixes and check

```console
$ ./labs/debug-containers/done/fix.sh
sk-db
3811968c6ad0164c3ae3474de8eeb9a8b20432e3e7a9e359d7abbc46516101ea
sk-web
ebbabc40daf76f8244852040408a6a8e84ad7f808da6903e5eb07025991626fe
sk-warmup
5b965faa04b3169a7bd8dcf73e8598ee813d64b42a976c63d3209ee765a2f873
$ docker ps -a --filter name=sk- --format '{{.Names}}: {{.Status}}'
sk-warmup: Exited (0) 10 seconds ago
sk-web: Up 11 seconds
sk-db: Up 12 seconds
$ docker logs sk-warmup
Loading 150 MB of cart data...
Warm-up done
$ curl -s localhost:8081 | head -n 4
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
$ docker stats --no-stream sk-db sk-web
CONTAINER ID   NAME      CPU %     MEM USAGE / LIMIT     MEM %     NET I/O          BLOCK I/O     PIDS
3811968c6ad0   sk-db     0.02%     21.65MiB / 125.8GiB   0.02%     866B / 126B      0B / 68.4MB   6
ebbabc40daf7   sk-web    0.00%     3.578MiB / 125.8GiB   0.00%     1.3kB / 1.64kB   0B / 12.3kB   3
```

## 6. Clean up

```console
$ ./labs/debug-containers/done/cleanup.sh
sk-db
sk-web
sk-warmup
```

