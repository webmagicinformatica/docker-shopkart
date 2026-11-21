# Lab: Debug three broken containers

`start/break.sh` starts three ShopKart containers, and each one is broken in a different way:

| Container | Symptom |
| --- | --- |
| `sk-db` | keeps restarting (crash loop) |
| `sk-web` | says "Up", but the page never loads (wrong port) |
| `sk-warmup` | dies a second after it starts (out of memory) |

You'll find each cause with `ps`, `logs`, `inspect`, `exec` and `stats`, then fix it in `start/fix.sh`. The answers are in `done/fix.sh`.

## 1. Break things

```bash
./labs/debug-containers/start/break.sh
sleep 10
docker ps -a --filter name=sk-
```

## 2. The crash loop: `sk-db`

```bash
docker ps -a --filter name=sk-db --format '{{.Names}}: {{.Status}}'
docker inspect sk-db --format 'restarts={{.RestartCount}} exit={{.State.ExitCode}} policy={{.HostConfig.RestartPolicy.Name}}'
docker logs sk-db
```

The restart policy `on-failure:5` keeps restarting it, and the log says why it fails every time: no superuser password.
Fix: add `-e POSTGRES_PASSWORD=...`. Never use `--restart always` to "fix" a crash: it only hides it.

## 3. The wrong port: `sk-web`

```bash
docker ps --filter name=sk-web --format '{{.Names}}: {{.Status}}  {{.Ports}}'
curl -sS localhost:8081
docker exec sk-web netstat -tln
```

`-p 8081:8080` sends traffic to port 8080 in the container, but nginx listens on **80**. Fix: `-p 8081:80`.
The rule: `-p <your port>:<the container's port>`, and the right side must match what the app listens on.

## 4. Out of memory: `sk-warmup`

```bash
docker ps -a --filter name=sk-warmup --format '{{.Names}}: {{.Status}}'
docker logs sk-warmup
docker inspect sk-warmup --format 'exit={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}} limit={{.HostConfig.Memory}}'
```

Exit code **137** = 128 + 9: the process got `SIGKILL`. `OOMKilled=true` says the kernel did it, because the container passed its 64 MB limit.
Fix: give it a limit that fits the job (`--memory 256m`), or make the job use less memory.

## 5. Apply the fixes and check

```bash
./labs/debug-containers/start/fix.sh     # after filling in the TODOs (or run done/fix.sh)
sleep 10
docker ps -a --filter name=sk- --format '{{.Names}}: {{.Status}}'
docker logs sk-warmup
curl -s localhost:8081 | head -n 4
docker stats --no-stream sk-db sk-web
```

## 6. Clean up

```bash
./labs/debug-containers/done/cleanup.sh
```

## Checkpoint

- [ ] You can explain each failure from its logs and `inspect` output
- [ ] `sk-db` is "Up", the page loads on 8081, `sk-warmup` printed "Warm-up done" and exited with 0
