# Debug three broken containers: tested run

Recorded on 2026-11-21 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings and sizes will differ.

The postgres and python images were pulled before this run, so the pull output is not shown.

## 1. Break things

```console
$ ./labs/debug-containers/start/break.sh
9e0a97d4f2d749789718d5e3082412231a63756b20aca365f3cc34e8dcc80bf0
e4edcd66fa4194861f7f2f3bc162a63888e1c565ca8c53d6c0349b68f149e2ef
cc65c2e9fc3873c79e70533a4aa7c0a65029998608891e8f6dfceebc828e0284
Three containers started. Now find out what's wrong: docker ps -a
$ docker ps -a --filter name=sk-
CONTAINER ID   IMAGE                       COMMAND                  CREATED          STATUS                        PORTS                                                 NAMES
cc65c2e9fc38   python:3.12.16-alpine3.24   "python -c 'print('L…"   10 seconds ago   Exited (137) 10 seconds ago                                                         sk-warmup
e4edcd66fa41   nginx:1.30.7-alpine         "/docker-entrypoint.…"   11 seconds ago   Up 10 seconds                 80/tcp, 0.0.0.0:8081->8080/tcp, [::]:8081->8080/tcp   sk-web
9e0a97d4f2d7   postgres:17.12-alpine       "docker-entrypoint.s…"   12 seconds ago   Exited (1) 6 seconds ago                                                            sk-db
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
a90ea4b17f79bdf05bb81f7097b4cc1d71626f63965363b044461a4d1e190cbc
sk-web
73471d73aad0aae587238fdc3e04be32a3e1d3c666a967942a6b0b0e39d2345b
sk-warmup
4ce0ffcd8d512ccf1de9776d2e9e3b767c435d6256f0274692d9f853b14279b6
$ docker ps -a --filter name=sk- --format '{{.Names}}: {{.Status}}'
sk-warmup: Exited (0) 10 seconds ago
sk-web: Up 11 seconds
sk-db: Up 11 seconds
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
a90ea4b17f79   sk-db     0.02%     21.59MiB / 125.8GiB   0.02%     866B / 126B      0B / 65.4MB   6
73471d73aad0   sk-web    0.00%     3.336MiB / 125.8GiB   0.00%     1.3kB / 1.64kB   0B / 12.3kB   3
```

## 6. Clean up

```console
$ ./labs/debug-containers/done/cleanup.sh
sk-db
sk-web
sk-warmup
```

