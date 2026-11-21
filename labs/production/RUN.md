# Find and fix a slow container and a memory leak: tested run

Recorded on 2026-11-21 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings and sizes will differ.

## 1. Start the stack

```console
$ docker compose -f labs/production/start/compose.yaml up -d --build --wait 2>&1 | tail -n 4
 Container shopkart-prod-api-1  Healthy
 Container shopkart-prod-db-1  Healthy
 Container shopkart-prod-web-1  Healthy
 Container shopkart-prod-redis-1  Healthy
$ docker compose -f labs/production/start/compose.yaml ps --format 'table {{.Service}}\t{{.Status}}'
SERVICE   STATUS
api       Up 25 seconds (healthy)
db        Up 25 seconds (healthy)
redis     Up 25 seconds
web       Up Less than a second
```

## 2. Symptom: ShopKart is slow

```console
$ time curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/api/products
200

real	0m0.024s
user	0m0.003s
sys	0m0.005s
$ python3 labs/production/load.py --requests 200 --concurrency 10 & sleep 6; docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.PIDs}}'; wait
NAME                    CPU %     MEM USAGE / LIMIT     PIDS
shopkart-prod-web-1     0.56%     4.168MiB / 125.8GiB   3
shopkart-prod-db-1      13.91%    35.36MiB / 256MiB     14
shopkart-prod-redis-1   0.17%     5.77MiB / 64MiB       7
shopkart-prod-api-1     20.84%    56.6MiB / 128MiB      12
200 requests in 14.7s  (14 req/s)
latency  p50 694 ms   p95 1170 ms
errors   0
```

## 3. Cause: a CPU limit that's far too low

```console
$ docker inspect shopkart-prod-api-1 --format 'NanoCpus={{.HostConfig.NanoCpus}} Memory={{.HostConfig.Memory}} PidsLimit={{.HostConfig.PidsLimit}}'
NanoCpus=200000000 Memory=134217728 PidsLimit=100
$ docker exec shopkart-prod-api-1 cat /sys/fs/cgroup/cpu.max /sys/fs/cgroup/cpu.stat | grep -E '^[0-9]|nr_throttled|throttled_usec'
20000 100000
nr_throttled 313
throttled_usec 39208232
```

## 4. Fix: give it a real CPU budget

```console
$ sed -i 's/cpus: "0.2"/cpus: "1.0"/' labs/production/start/compose.yaml
$ docker compose -f labs/production/start/compose.yaml up -d --wait 2>&1 | tail -n 2
 Container shopkart-prod-redis-1  Healthy
 Container shopkart-prod-web-1  Healthy
$ python3 labs/production/load.py --requests 200 --concurrency 10
200 requests in 2.5s  (79 req/s)
latency  p50 112 ms   p95 213 ms
errors   0
```

## 5. Symptom: memory only goes up

```console
$ docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' shopkart-prod-api-1
shopkart-prod-api-1 53.69MiB / 128MiB
$ python3 labs/production/load.py --requests 500 --concurrency 20
500 requests in 7.3s  (69 req/s)
latency  p50 255 ms   p95 540 ms
errors   0
$ docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' shopkart-prod-api-1
shopkart-prod-api-1 70.39MiB / 128MiB
$ python3 labs/production/load.py --requests 500 --concurrency 20
500 requests in 7.0s  (71 req/s)
latency  p50 244 ms   p95 526 ms
errors   0
$ docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' shopkart-prod-api-1
shopkart-prod-api-1 85.56MiB / 128MiB
```

## 6. Until the kernel kills it

```console
$ python3 labs/production/load.py --requests 3000 --concurrency 20
3000 requests in 19.9s  (151 req/s)
latency  p50 23 ms   p95 357 ms
errors   1635
$ docker events --since 2m --until 0s --filter container=$(docker compose -f labs/production/start/compose.yaml ps -q api) --filter event=oom --filter event=die --filter event=start --format '{{.Action}} exitCode={{index .Actor.Attributes "exitCode"}}'
start exitCode=
oom exitCode=
die exitCode=137
start exitCode=
$ docker inspect shopkart-prod-api-1 --format 'RestartCount={{.RestartCount}} StartedAt={{.State.StartedAt}}'
RestartCount=1 StartedAt=2026-11-21T20:51:46.129903279Z
$ docker compose -f labs/production/start/compose.yaml logs api --tail 6
api-1  | INFO:     172.19.0.5:60116 - "GET /api/products/4?visitor=v1369 HTTP/1.1" 200 OK
api-1  | INFO:     172.19.0.5:60000 - "GET /api/products/5?visitor=v1358 HTTP/1.1" 200 OK
api-1  | INFO:     Started server process [1]
api-1  | INFO:     Waiting for application startup.
api-1  | INFO:     Application startup complete.
api-1  | INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

## 7. Cause: an unbounded in-memory list

```console
$ diff labs/production/start/recent.py app/api/shopkart_api/recent.py
1c1,2
< """Recently viewed products, kept per visitor (newest first, at most 10).
---
> """Recently viewed products, kept per visitor (newest first, at most 10)."""
> from collections import OrderedDict, deque
3,5c4,5
< Version 2: "keeps a snapshot of every view, for debugging".
< """
< import json
---
> MAX_ITEMS = 10
> MAX_VISITORS = 10_000
7c7
< _views: dict[str, list[dict]] = {}
---
> _views: "OrderedDict[str, deque[int]]" = OrderedDict()
11,12c11,17
<     snapshot = json.dumps(product) * 300          # what the page looked like, for support tickets
<     _views.setdefault(visitor, []).append({"product": dict(product), "snapshot": snapshot})
---
>     views = _views.pop(visitor, None) or deque(maxlen=MAX_ITEMS)
>     if product["id"] in views:
>         views.remove(product["id"])
>     views.appendleft(product["id"])
>     _views[visitor] = views
>     while len(_views) > MAX_VISITORS:
>         _views.popitem(last=False)
16,21c21
<     ids: list[int] = []
<     for view in reversed(_views.get(visitor, [])):
<         pid = view["product"]["id"]
<         if pid not in ids:
<             ids.append(pid)
<     return ids[:10]
---
>     return list(_views.get(visitor, []))
```

## 8. Fix: keep at most 10 views per visitor, and a cap on visitors

```console
$ cp app/api/shopkart_api/recent.py labs/production/start/recent.py
$ docker compose -f labs/production/start/compose.yaml restart api 2>&1 | tail -n 1
 Container shopkart-prod-api-1  Started
$ python3 labs/production/load.py --requests 3000 --concurrency 20
3000 requests in 40.8s  (74 req/s)
latency  p50 254 ms   p95 437 ms
errors   0
$ docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' shopkart-prod-api-1
shopkart-prod-api-1 51.55MiB / 128MiB
$ python3 labs/production/load.py --requests 3000 --concurrency 20
3000 requests in 38.4s  (78 req/s)
latency  p50 241 ms   p95 405 ms
errors   0
$ docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' shopkart-prod-api-1
shopkart-prod-api-1 52.1MiB / 128MiB
```

## 9. Log rotation is on

```console
$ docker inspect shopkart-prod-api-1 --format '{{.HostConfig.LogConfig.Type}} {{json .HostConfig.LogConfig.Config}}'
json-file {"max-file":"3","max-size":"10m"}
```

## Clean up

```console
$ docker compose -f labs/production/start/compose.yaml down -v 2>&1 | tail -n 2
 Volume shopkart-prod_db-data  Removed
 Network shopkart-prod_default  Removed
$ git checkout -- labs/production/start/
```

