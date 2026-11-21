# Lab: Scan and fix ShopKart; harden the running stack (two parts)

**Part 1:** scan the images from the slim-image lab with **Trivy**, read the findings, fix the Dockerfile, make the scan a pass/fail gate, and export an SBOM.
**Part 2:** run the whole stack as non-root, read-only, with no Linux capabilities and no privilege escalation, then **prove** each of those from inside the containers.

Files: `trivy.sh` (Trivy in a container), `count.tpl` (a one-line-per-target report), `start/` (TODOs) and `done/`: `Dockerfile`, `compose.yaml`, `nginx.conf`.
You need `shopkart-api:fat` and `shopkart-api:small` from the slim-image lab.

> **Why Trivy?** It is open source (Apache-2.0), runs as a container, and needs no account. Docker Scout (`docker scout cves`) does the same job but needs a Docker account login, so it's optional here.

## Part 1

### 1. Scan the fat image

```bash
cat labs/security/trivy.sh
./labs/security/trivy.sh image --quiet --scanners vuln --severity HIGH,CRITICAL --format template --template @labs/security/count.tpl shopkart-api:fat | grep -v ': 0$'
```

The first run downloads Trivy's vulnerability database (cached in the `trivy-cache` volume). Hundreds of HIGH and CRITICAL findings, nearly all in Debian packages the app never uses.

### 2. Scan the small image

```bash
./labs/security/trivy.sh image --quiet --scanners vuln --severity HIGH,CRITICAL --format template --template @labs/security/count.tpl shopkart-api:small | grep -v ': 0$'
./labs/security/trivy.sh image --quiet --scanners vuln --severity HIGH,CRITICAL --pkg-types os --table-mode detailed shopkart-api:small 2>&1 | head -n 13
```

Far fewer, and the table's **Fixed Version** column says the fixes already exist: the base image was built before they came out. Your numbers depend on the day you scan.

### 3. Fix it

In `start/Dockerfile`: upgrade the OS packages in the final stage and run as an unprivileged user (see `done/Dockerfile`).

```bash
docker build -f labs/security/start/Dockerfile -t shopkart-api:secure app/api
./labs/security/trivy.sh image --quiet --scanners vuln --severity HIGH,CRITICAL --format template --template @labs/security/count.tpl shopkart-api:secure | grep -v ': 0$' || echo 'no HIGH or CRITICAL vulnerabilities'
```

### 4. Make it a gate

`--exit-code 1` makes Trivy fail when it finds something; `--ignore-unfixed` skips findings nobody can fix yet. This is the line the CI/CD lab puts in the pipeline.

```bash
./labs/security/trivy.sh image --quiet --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed --format template --template @labs/security/count.tpl shopkart-api:small > /dev/null; echo "exit code: $?"
./labs/security/trivy.sh image --quiet --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed --format template --template @labs/security/count.tpl shopkart-api:secure > /dev/null; echo "exit code: $?"
```

### 5. An SBOM

A Software Bill of Materials lists every package in the image, so you can answer "are we affected?" the day a new CVE comes out.

```bash
./labs/security/trivy.sh image --quiet --format cyclonedx --output sbom-shopkart.json shopkart-api:secure
python3 -c "import json; d = json.load(open('sbom-shopkart.json')); libs = [c['name'] + ' ' + c.get('version', '') for c in d['components'] if c['type'] == 'library']; print(len(libs), 'libraries, e.g.', ', '.join(sorted(libs)[:6]))"
```

Signing and provenance go one step further: BuildKit already attaches a provenance attestation to every build (`exporting attestation manifest` in the build log), and tools like Sigstore `cosign` sign the pushed image so a server can refuse unsigned ones.

## Part 2

### 6. Start the hardened stack

`done/compose.yaml` gives every service the same YAML anchor:

```yaml
x-hardening: &hardening
  read_only: true                          # root filesystem is read-only
  cap_drop: [ALL]                          # no Linux capabilities
  security_opt: ["no-new-privileges:true"] # setuid binaries can't gain privileges
  pids_limit: 100                          # no fork bombs
```

Plus a non-root `user` per service, `tmpfs` where a service must write (`/tmp`, PostgreSQL's socket folder), memory limits, and `nginx-unprivileged` on port 8080 for the web.

```bash
docker compose -f labs/security/start/compose.yaml up -d --build --wait     # after the TODOs (or use done/)
curl -s localhost:8080/health; echo
```

### 7. Prove it

```bash
docker run --rm python:3.12.16-alpine3.24 sh -c 'id; grep -E "^(CapEff|NoNewPrivs)" /proc/1/status'    # a default container, for comparison
docker compose -f labs/security/done/compose.yaml exec api sh -c 'id; grep -E "^(CapEff|NoNewPrivs)" /proc/1/status'
docker compose -f labs/security/done/compose.yaml exec api touch /app/hacked.txt
docker compose -f labs/security/done/compose.yaml exec api sh -c 'echo scratch > /tmp/ok.txt && ls /tmp'
docker compose -f labs/security/done/compose.yaml exec web id
docker compose -f labs/security/done/compose.yaml exec db id
docker inspect shopkart-secure-api-1 --format 'ReadOnly={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} SecurityOpt={{.HostConfig.SecurityOpt}} PidsLimit={{.HostConfig.PidsLimit}} Memory={{.HostConfig.Memory}}'
docker compose -f labs/security/done/compose.yaml exec api sh -c 'for i in $(seq 1 150); do sleep 15 & done; wait' 2>&1 | sort | uniq -c
```

| Check | Default container | Hardened |
| --- | --- | --- |
| User | root (uid 0) | 10001 / nginx / postgres |
| `CapEff` | `00000000a80425fb` (14 capabilities) | `0000000000000000` (none) |
| `NoNewPrivs` | 0 | 1 |
| Write to `/app` | works | `Read-only file system` |
| 150 processes | works | `can't fork` |

### 8. The Docker socket is the keys to the host

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker:29.10.0-cli docker ps --format '{{.Names}}'
```

Any container with the socket mounted can see, stop or start **every** container, including a privileged one that mounts the host's disk. Mount it only into tools you trust completely (Trivy here reads images through it). Rootless Docker and user namespaces (`userns-remap`) reduce the damage if a container does break out.

### 9. Clean up

```bash
docker compose -f labs/security/done/compose.yaml down -v
rm sbom-shopkart.json
```

## Checkpoint

- [ ] The fixed image has no fixable HIGH or CRITICAL findings, and the gate exits 0
- [ ] `sbom-shopkart.json` lists the image's packages
- [ ] Every service runs as non-root, with `CapEff` all zeros and a read-only root filesystem
