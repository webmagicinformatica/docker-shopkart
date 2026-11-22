# Capstone: tested run

Recorded on 2026-11-22 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3, Node.js 24.22.3, Python 3.12.16. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings, sizes and vulnerability counts will differ (Trivy's database changes daily).

## The app's own tests, without Docker

```console
$ cd capstone/start/api && npm ci --no-audit --no-fund && npm test 2>&1 | tail -n 8; cd /workspaces/docker-shopkart

added 20 packages in 3s
ℹ tests 8
ℹ suites 0
ℹ pass 8
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 842.816684
$ cd capstone/start/worker && pip install --quiet --disable-pip-version-check -r requirements-dev.txt && python -m pytest -q -p no:cacheprovider; cd /workspaces/docker-shopkart
.....                                                                    [100%]
5 passed in 0.03s
```

## check.sh against `start/` (the app as handed over: no Docker files)

Everything fails, as it should. The exit code is 1.

```console
$ ./capstone/check.sh; echo "exit code: $?"
QuickBite capstone check: capstone/start
Docker 29.10.0, Compose 2.40.3

 1  FAIL  Dockerfiles: api, worker and web each have a Dockerfile and a .dockerignore
          -> missing: api/Dockerfile api/.dockerignore worker/Dockerfile worker/.dockerignore web/Dockerfile web/.dockerignore
 2  FAIL  Multi-stage: api and worker have test and runtime stages
          ->  api: no Dockerfile; worker: no Dockerfile;
 3  FAIL  Tests run in the build: docker build --target test passes for api and worker
          ->  api: no Dockerfile; worker: no Dockerfile;
 4  FAIL  Build: docker compose build succeeds
          -> no compose.yaml
 5  FAIL  Pinned: every base image and service image has an exact version (no latest)
          ->  api: no Dockerfile; worker: no Dockerfile; web: no Dockerfile; no compose.yaml;
 6  FAIL  Small images: api <= 300 MB, worker <= 200 MB, web <= 150 MB
          ->  api: no image; worker: no image; web: no image;
 7  FAIL  Non-root images: api, worker and web set USER to an unprivileged user
          ->  api: no image; worker: no image; web: no image;
 8  FAIL  Image healthchecks: api, worker and web have a HEALTHCHECK
          ->  api: no image; worker: no image; web: no image;
 9  FAIL  Compose: one compose.yaml with web, api, worker, db and redis
          -> no compose.yaml
10  FAIL  Health-gated start: every depends_on waits for service_healthy
          -> no compose.yaml
11  FAIL  Named volumes: PostgreSQL and Redis data live in named volumes
          -> no compose.yaml
12  FAIL  Networks: only web publishes a port; web can't reach db or redis
          -> no compose.yaml
13  FAIL  Secrets and config: DB password is a Compose secret (git-ignored, not in any image), .env.example, no password in env
          -> no compose.yaml
14  FAIL  Stack up: docker compose up --wait succeeds and all 5 services are healthy
          -> not built
15  FAIL  End to end: an order placed through web is cooked by the worker
          -> stack not running or web publishes no port 8080
16  FAIL  Persistence: the order survives docker compose down and up
          -> no order to look for
17  FAIL  Hardening: read-only root filesystem on all 5 services
          -> no containers
18  FAIL  Hardening: cap_drop ALL on all 5 services
          -> no containers
19  FAIL  Hardening: no-new-privileges on all 5 services
          -> no containers
20  FAIL  Hardening: memory and PID limits on all 5 services
          -> no containers
21  FAIL  Non-root at run time: no process in any of the 5 containers runs as uid 0
          -> stack not running
22  FAIL  Dev override: compose.dev.yaml has develop.watch for api, worker and web, and an edit syncs live
          -> no compose.dev.yaml
23  FAIL  Trivy: no fixable HIGH or CRITICAL vulnerabilities in api, worker and web
          -> nothing built
24  FAIL  Pipeline: pipeline.yml tests, builds with cache, scans (fails on HIGH/CRITICAL) and pushes to GHCR
          -> no pipeline.yml

Result: 0 of 24 PASS, 24 FAIL
Also check by hand (see BRIEF.md): your pipeline ran green on GitHub Actions and pushed 3 images to ghcr.io.
exit code: 1
```

## check.sh against `done/` (the reference solution)

All 24 pass and the exit code is 0. This was a second run, so the images, the build cache and Trivy's database were already there; a first run on a fresh codespace takes a few minutes longer (image pulls, builds, the Trivy database download).

```console
$ time ./capstone/check.sh capstone/done; echo "exit code: $?"
QuickBite capstone check: capstone/done
Docker 29.10.0, Compose 2.40.3

(created a random /workspaces/docker-shopkart/capstone/done/secrets/db_password.txt for this check)
 1  PASS  Dockerfiles: api, worker and web each have a Dockerfile and a .dockerignore
 2  PASS  Multi-stage: api and worker have test and runtime stages
 3  PASS  Tests run in the build: docker build --target test passes for api and worker
 4  PASS  Build: docker compose build succeeds
 5  PASS  Pinned: every base image and service image has an exact version (no latest)
 6  PASS  Small images: api <= 300 MB, worker <= 200 MB, web <= 150 MB (api 225 MB, worker 127 MB, web 110 MB)
 7  PASS  Non-root images: api, worker and web set USER to an unprivileged user
 8  PASS  Image healthchecks: api, worker and web have a HEALTHCHECK
 9  PASS  Compose: one compose.yaml with web, api, worker, db and redis
10  PASS  Health-gated start: every depends_on waits for service_healthy
11  PASS  Named volumes: PostgreSQL and Redis data live in named volumes
12  PASS  Networks: only web publishes a port; web can't reach db or redis
13  PASS  Secrets and config: DB password is a Compose secret (git-ignored, not in any image), .env.example, no password in env
14  PASS  Stack up: docker compose up --wait succeeds and all 5 services are healthy
15  PASS  End to end: an order placed through web is cooked by the worker (ready after 3 s)
16  PASS  Persistence: the order survives docker compose down and up
17  PASS  Hardening: read-only root filesystem on all 5 services
18  PASS  Hardening: cap_drop ALL on all 5 services
19  PASS  Hardening: no-new-privileges on all 5 services
20  PASS  Hardening: memory and PID limits on all 5 services
21  PASS  Non-root at run time: no process in any of the 5 containers runs as uid 0
22  PASS  Dev override: compose.dev.yaml has develop.watch for api, worker and web, and an edit syncs live
23  PASS  Trivy: no fixable HIGH or CRITICAL vulnerabilities in api, worker and web (api 0, worker 0, web 0)
24  PASS  Pipeline: pipeline.yml tests, builds with cache, scans (fails on HIGH/CRITICAL) and pushes to GHCR

Result: 24 of 24 PASS, 0 FAIL
Also check by hand (see BRIEF.md): your pipeline ran green on GitHub Actions and pushed 3 images to ghcr.io.

real	1m46.975s
user	0m7.757s
sys	0m4.120s
exit code: 0
```

## The reference pipeline on GitHub Actions

`.github/workflows/capstone.yml` (the same as `done/pipeline.yml`, pointed at `capstone/done`) ran on the push of the capstone, commit `010b553`: [run 45004748643](https://github.com/webmagicinformatica/docker-shopkart/actions/runs/45004748643). Output from `gh` on the test machine:

```console
$ gh run view 45004748643

✓ main Capstone (QuickBite reference) · 45004748643
Triggered via push about 4 minutes ago

JOBS
✓ test in 14s (ID 137153713714)
✓ build-scan-push (web) in 46s (ID 137153776036)
✓ build-scan-push (api) in 1m27s (ID 137153776044)
✓ build-scan-push (worker) in 1m14s (ID 137153776077)
✓ stack-test in 53s (ID 137153776326)

$ gh run view 45004748643 --log | grep -E "ℹ pass|passed in|pushing manifest .* done$|order [0-9]+:" | cut -f1,3 | sed -E 's/^([^\t]*)\t[^ ]+ /\1\t/'
test	ℹ pass 8
test	5 passed in 0.02s
build-scan-push (web)	#13 pushing manifest for ghcr.io/webmagicinformatica/quickbite-web:sha-010b553@sha256:f3c11e2bb46206ae3e5efdba4a553a1314653777cd12d98e1bbbc5cc8524a624 2.8s done
build-scan-push (web)	#13 pushing manifest for ghcr.io/webmagicinformatica/quickbite-web:latest@sha256:f3c11e2bb46206ae3e5efdba4a553a1314653777cd12d98e1bbbc5cc8524a624 1.1s done
build-scan-push (api)	#21 pushing manifest for ghcr.io/webmagicinformatica/quickbite-api:sha-010b553@sha256:221aaf0935f9c32d36f23c00aaa6d6f37b5736f529b30412a37d173d543cba3e 3.2s done
build-scan-push (api)	#21 pushing manifest for ghcr.io/webmagicinformatica/quickbite-api:latest@sha256:221aaf0935f9c32d36f23c00aaa6d6f37b5736f529b30412a37d173d543cba3e 1.3s done
build-scan-push (worker)	#17 pushing manifest for ghcr.io/webmagicinformatica/quickbite-worker:sha-010b553@sha256:8f636e706b10bfb57f8f851499849d5a7e628ac25417a2921432b3eba3d7878f 3.0s done
build-scan-push (worker)	#17 pushing manifest for ghcr.io/webmagicinformatica/quickbite-worker:latest@sha256:8f636e706b10bfb57f8f851499849d5a7e628ac25417a2921432b3eba3d7878f 1.3s done
stack-test	order 1: preparing
stack-test	order 1: preparing
stack-test	order 1: preparing
stack-test	order 1: ready
$ gh run view 45004748643 --log | grep -E "│ quickbite-[a-z]+:candidate" | cut -f1,3 | sed -E 's/^([^\t]*)\t[^ ]+ /\1\t/'
build-scan-push (web)	│ quickbite-web:candidate (alpine 3.24.2) │ alpine │        0        │
build-scan-push (api)	│ quickbite-api:candidate (alpine 3.24.4)            │  alpine  │        0        │
build-scan-push (worker)	│ quickbite-worker:candidate (alpine 3.24.4)                                    │   alpine   │        0        │
```

Trivy's summary: zero fixable HIGH or CRITICAL findings in each image (any would have failed the job with exit code 1, before the push steps). The images are at `ghcr.io/webmagicinformatica/quickbite-api`, `quickbite-worker` and `quickbite-web`.

## Clean up

`check.sh` removed its own containers, networks and volumes (project `qbcheck`). Left behind on purpose: the `quickbite-*:local` images and the `trivy-cache` volume, which make the next run fast. To remove them too:

```bash
docker image rm quickbite-api:local quickbite-worker:local quickbite-web:local
docker volume rm trivy-cache
```
