# Lab: Find and fix a slow container and a memory leak

ShopKart's new release went out and two things are wrong: pages are slow, and the API keeps getting restarted. Put load on the stack, read `docker stats`, `inspect` and `events`, find both causes, and fix them.

Files: `load.py` (a small load generator, standard library only), `start/compose.yaml` + `start/recent.py` (the broken release), `done/` (fixed).
The stack in `start/` mounts `start/recent.py` over the API's "recently viewed products" module, so you can fix it without rebuilding.

`compose.yaml` already has the production habits from the lessons: `restart: unless-stopped`, health checks with a `start_period`, memory/CPU/PID limits under `deploy.resources.limits`, and **log rotation** (`json-file`, 10 MB × 3 files) on every service.

## 1. Start the stack

```bash
docker compose -f labs/production/start/compose.yaml up -d --build --wait
docker compose -f labs/production/start/compose.yaml ps --format 'table {{.Service}}\t{{.Status}}'
```

## 2. Symptom: it's slow

```bash
time curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/api/products
python3 labs/production/load.py --requests 200 --concurrency 10 & sleep 6; docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.PIDs}}'; wait
```

(`&` runs the load in the background so `docker stats` can look while it runs.)

Under load, the API sits at about **20 % CPU** and won't go higher, while the machine has CPU to spare. That's a ceiling, not hard work.

## 3. Cause: the CPU limit

```bash
docker inspect shopkart-prod-api-1 --format 'NanoCpus={{.HostConfig.NanoCpus}} Memory={{.HostConfig.Memory}} PidsLimit={{.HostConfig.PidsLimit}}'
docker exec shopkart-prod-api-1 cat /sys/fs/cgroup/cpu.max /sys/fs/cgroup/cpu.stat | grep -E '^[0-9]|nr_throttled|throttled_usec'
```

`NanoCpus=200000000` is 0.2 of a CPU. `cpu.max` says the same in kernel terms (20 ms of CPU every 100 ms), and `nr_throttled` counts how often the kernel paused the API because it used its share.

## 4. Fix: a real CPU budget

Change `cpus: "0.2"` to `cpus: "1.0"` in `start/compose.yaml`, then apply it:

```bash
sed -i 's/cpus: "0.2"/cpus: "1.0"/' labs/production/start/compose.yaml
docker compose -f labs/production/start/compose.yaml up -d --wait
python3 labs/production/load.py --requests 200 --concurrency 10
```

Compose recreates only the API. Throughput goes up about five times and p95 latency drops from over a second to about 200 ms.

## 5. Symptom: memory only goes up

```bash
docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' shopkart-prod-api-1
python3 labs/production/load.py --requests 500 --concurrency 20
docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' shopkart-prod-api-1
python3 labs/production/load.py --requests 500 --concurrency 20
docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' shopkart-prod-api-1
```

A healthy service levels off after warm-up. This one grows with every request.

## 6. Until the kernel kills it

```bash
python3 labs/production/load.py --requests 3000 --concurrency 20
docker events --since 2m --until 0s --filter container=$(docker compose -f labs/production/start/compose.yaml ps -q api) --filter event=oom --filter event=die --filter event=start --format '{{.Action}} exitCode={{index .Actor.Attributes "exitCode"}}'
docker inspect shopkart-prod-api-1 --format 'RestartCount={{.RestartCount}} StartedAt={{.State.StartedAt}}'
docker compose -f labs/production/start/compose.yaml logs api --tail 6
```

`oom`, then `die` with exit code **137**, then `start`: the API hit its 128 MB limit, the kernel killed it, and the restart policy brought it back. The load test saw errors while it was down. The restart policy hides the problem; it doesn't fix it.

## 7. Cause: an unbounded list

Memory grows with **requests**, so look at what runs on every request. The release changed one module:

```bash
diff labs/production/start/recent.py app/api/shopkart_api/recent.py
```

The new `recent.py` appends every view, plus a ~27 KB "snapshot", to a dictionary that is never trimmed, and a new visitor ID makes a new entry.

## 8. Fix: bound it

Keep at most 10 views per visitor and cap the number of visitors (that's what `app/api/shopkart_api/recent.py` and `done/recent.py` do):

```bash
cp app/api/shopkart_api/recent.py labs/production/start/recent.py
docker compose -f labs/production/start/compose.yaml restart api
python3 labs/production/load.py --requests 3000 --concurrency 20
docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' shopkart-prod-api-1
python3 labs/production/load.py --requests 3000 --concurrency 20
docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' shopkart-prod-api-1
```

6,000 requests, no errors, and memory stays flat.

## 9. Log rotation

```bash
docker inspect shopkart-prod-api-1 --format '{{.HostConfig.LogConfig.Type}} {{json .HostConfig.LogConfig.Config}}'
```

Without `max-size`, the default `json-file` driver keeps every log line forever, and a chatty container can fill the disk.

## Clean up

```bash
docker compose -f labs/production/start/compose.yaml down -v
git checkout -- labs/production/start/      # put the broken release back, to practise again
```

## Checkpoint

- [ ] You found the CPU cap from `docker stats` + `inspect`, and p95 latency dropped after the fix
- [ ] You saw `oom` and `die` (137) in `docker events`
- [ ] After the `recent.py` fix, two rounds of 3,000 requests left memory flat with 0 errors
