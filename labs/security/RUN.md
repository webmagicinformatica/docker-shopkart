# Scan and fix the ShopKart image; harden the running stack (two parts): tested run

Recorded on 2026-11-21 in this repo's dev container (the same image and Docker-in-Docker setup as the codespace): Docker 29.10.0, Compose 2.40.3. Commands run from the repo root, `/workspaces/docker-shopkart`. Your IDs, hashes, timings and sizes will differ.

Uses `shopkart-api:fat` and `shopkart-api:small` from the slim-image lab.

## Part 1. Scan the fat image

```console
$ cat labs/security/trivy.sh
#!/usr/bin/env bash
# Run Trivy (open-source scanner, Apache-2.0) from its container: nothing to install, no account.
# It reads local images through the Docker socket and keeps its vulnerability database in a volume.
#   ./labs/security/trivy.sh image shopkart-api:small
exec docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v trivy-cache:/root/.cache \
  -v "$PWD:/work" -w /work \
  aquasec/trivy:0.76.2 "$@"
$ cat labs/security/count.tpl
{{- range . }}{{ .Target }}: {{ len .Vulnerabilities }}
{{ end -}}
$ ./labs/security/trivy.sh image --quiet --scanners vuln --severity HIGH,CRITICAL --format template --template @labs/security/count.tpl shopkart-api:fat | grep -v ': 0$'
shopkart-api:fat (debian 13.7): 552
```

## Part 1. Scan the small image

```console
$ ./labs/security/trivy.sh image --quiet --scanners vuln --severity HIGH,CRITICAL --format template --template @labs/security/count.tpl shopkart-api:small | grep -v ': 0$'
shopkart-api:small (alpine 3.24.4): 16
$ ./labs/security/trivy.sh image --quiet --scanners vuln --severity HIGH,CRITICAL shopkart-api:small 2>&1 | head -n 14

Report Summary

┌───────────────────────────────────────────────────────────────────────────────┬────────────┬─────────────────┐
│                                    Target                                     │    Type    │ Vulnerabilities │
├───────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┤
│ shopkart-api:small (alpine 3.24.4)                                            │   alpine   │       16        │
├───────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┤
│ usr/local/lib/python3.12/site-packages/pip-25.0.1.dist-info/METADATA          │ python-pkg │        0        │
├───────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┤
│ venv/lib/python3.12/site-packages/annotated_doc-0.0.7.dist-info/METADATA      │ python-pkg │        0        │
├───────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┤
│ venv/lib/python3.12/site-packages/annotated_types-0.8.0.dist-info/METADATA    │ python-pkg │        0        │
├───────────────────────────────────────────────────────────────────────────────┼────────────┼─────────────────┤
```

## Part 1. Fix: patched packages, non-root user

```console
$ diff labs/security/start/Dockerfile labs/security/done/Dockerfile
2c2,5
< # The small image from the slim-image lab. Scan it, then fix what the scanner finds.
---
> # ShopKart API, scanned and fixed: patched OS packages, a non-root user, a health check.
> # (Same as app/api/Dockerfile.)
> 
> # ---- build stage: install dependencies into a virtualenv ----
8a12
> # ---- runtime stage: only the venv and the app ----
10,12c14,20
< ENV PATH=/venv/bin:$PATH PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
< # TODO: upgrade the OS packages (apk upgrade --no-cache) so the fixed versions are installed
< # TODO: create an unprivileged user with uid 10001 (adduser -S -u 10001 -H shopkart)
---
> ARG APP_VERSION=dev
> ENV PATH=/venv/bin:$PATH \
>     PYTHONDONTWRITEBYTECODE=1 \
>     PYTHONUNBUFFERED=1 \
>     APP_VERSION=$APP_VERSION
> # Patch the OS packages, then add an unprivileged user
> RUN apk upgrade --no-cache && adduser -S -u 10001 -H shopkart
15,16c23,24
< COPY . .
< # TODO: switch to that user (USER 10001)
---
> COPY --chown=root:root . .
> USER 10001
17a26,27
> HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
>   CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]
$ docker build -f labs/security/done/Dockerfile -t shopkart-api:secure app/api
[... 52 earlier lines of output cut ...]
#14 naming to docker.io/library/shopkart-api:secure done
#14 unpacking to docker.io/library/shopkart-api:secure 0.0s done
#14 DONE 0.2s
$ ./labs/security/trivy.sh image --quiet --scanners vuln --severity HIGH,CRITICAL --format template --template @labs/security/count.tpl shopkart-api:secure | grep -v ': 0$' || echo 'no HIGH or CRITICAL vulnerabilities'
no HIGH or CRITICAL vulnerabilities
```

## Part 1. A scan that can fail a build

```console
$ ./labs/security/trivy.sh image --quiet --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed --format template --template @labs/security/count.tpl shopkart-api:small > /dev/null; echo "exit code: $?"
exit code: 1
$ ./labs/security/trivy.sh image --quiet --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed --format template --template @labs/security/count.tpl shopkart-api:secure > /dev/null; echo "exit code: $?"
exit code: 0
```

## Part 1. An SBOM: the list of everything inside

```console
$ ./labs/security/trivy.sh image --quiet --format cyclonedx --output sbom-shopkart.json shopkart-api:secure
$ python3 -c "import json; d = json.load(open('sbom-shopkart.json')); libs = [c['name'] + ' ' + c.get('version', '') for c in d['components'] if c['type'] == 'library']; print(len(libs), 'libraries, e.g.', ', '.join(sorted(libs)[:6]))"
57 libraries, e.g. .python-rundeps 20261105.193119, alpine-baselayout 3.7.2-r1, alpine-baselayout-data 3.7.2-r1, alpine-keys 2.6-r0, alpine-release 3.24.4-r0, annotated-doc 0.0.7
```

## Part 2. Start the hardened stack

```console
$ docker compose -f labs/security/done/compose.yaml up -d --build --wait 2>&1 | tail -n 4
 Container shopkart-secure-api-1  Healthy
 Container shopkart-secure-web-1  Healthy
 Container shopkart-secure-redis-1  Healthy
 Container shopkart-secure-db-1  Healthy
$ curl -s localhost:8080/health; echo
{"status":"ok","db":"ok","cart":"ok"}
```

## Part 2. Prove it

```console
$ docker run --rm python:3.12.16-alpine3.24 sh -c 'id; grep -E "^(CapEff|NoNewPrivs)" /proc/1/status'
uid=0(root) gid=0(root) groups=0(root),0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)
CapEff:	00000000a80425fb
NoNewPrivs:	0
$ docker compose -f labs/security/done/compose.yaml exec api sh -c 'id; grep -E "^(CapEff|NoNewPrivs)" /proc/1/status'
uid=10001(shopkart) gid=10001 groups=10001
CapEff:	0000000000000000
NoNewPrivs:	1
$ docker compose -f labs/security/done/compose.yaml exec api touch /app/hacked.txt
touch: /app/hacked.txt: Read-only file system
$ docker compose -f labs/security/done/compose.yaml exec api sh -c 'echo scratch > /tmp/ok.txt && ls /tmp'
ok.txt
$ docker compose -f labs/security/done/compose.yaml exec web id
uid=101(nginx) gid=101(nginx) groups=101(nginx)
$ docker compose -f labs/security/done/compose.yaml exec db id
uid=70(postgres) gid=70(postgres) groups=70(postgres)
$ docker inspect shopkart-secure-api-1 --format 'ReadOnly={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} SecurityOpt={{.HostConfig.SecurityOpt}} PidsLimit={{.HostConfig.PidsLimit}} Memory={{.HostConfig.Memory}}'
ReadOnly=true CapDrop=[ALL] SecurityOpt=[no-new-privileges:true] PidsLimit=100 Memory=268435456
$ docker compose -f labs/security/done/compose.yaml exec api sh -c 'for i in $(seq 1 150); do sleep 15 & done; wait' 2>&1 | sort | uniq -c
      1 sh: can't fork: Resource temporarily unavailable
```

## Part 2. The Docker socket is the keys to the host

```console
$ docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker:29.10.0-cli docker ps --format '{{.Names}}'
Unable to find image 'docker:29.10.0-cli' locally
29.10.0-cli: Pulling from library/docker
c01e603afa82: Pulling fs layer
881fc932939e: Pulling fs layer
e79a20f65ccf: Pulling fs layer
4f4fb700ef54: Pulling fs layer
80a1fa15fb80: Pulling fs layer
554970c1d0af: Pulling fs layer
dd5c7ebbff8d: Pulling fs layer
c0f0ba247ae4: Pulling fs layer
a5da4a42f190: Pulling fs layer
d5681b4d7626: Pulling fs layer
881fc932939e: Already exists
e79a20f65ccf: Already exists
4f4fb700ef54: Already exists
a5da4a42f190: Already exists
c01e603afa82: Already exists
80a1fa15fb80: Already exists
554970c1d0af: Already exists
dd5c7ebbff8d: Already exists
c0f0ba247ae4: Already exists
d5681b4d7626: Already exists
33bba5e636b0: Download complete
Digest: sha256:34507eb5069d8be82c95dd3b6987d4250fd5fee49b82e2509b7d7a7030740d6d
Status: Downloaded newer image for docker:29.10.0-cli
stoic_benz
shopkart-secure-web-1
shopkart-secure-api-1
shopkart-secure-db-1
shopkart-secure-redis-1
```

## Clean up

```console
$ docker compose -f labs/security/done/compose.yaml down -v 2>&1 | tail -n 2
 Volume shopkart-secure_db-data  Removed
 Network shopkart-secure_default  Removed
$ rm sbom-shopkart.json
```

