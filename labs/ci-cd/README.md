# Lab: Docker in CI/CD (two parts)

**Part 1:** a GitHub Actions pipeline that tests the API, builds the API and web images with layer caching, smoke-tests and scans them, and pushes them to GitHub Container Registry.
**Part 2:** deploy the stack from those images to a server over SSH with Docker Compose, roll out a new version, and roll back.

Files: `start/pipeline.yml` (TODOs), `done/pipeline.yml`, `server/` (a practice server), `deploy/compose.yaml` (the stack as it runs on a server).

> **No cloud account needed.** The "server" in Part 2 is a container on your codespace that runs its own Docker engine and an SSH server. Everything you do to it is what you would do to a real Linux VM.

## Part 1: the pipeline

### 1. Add the workflow

```bash
cp labs/ci-cd/start/pipeline.yml .github/workflows/pipeline.yml     # fill in the TODOs (or copy done/)
```

| Job / step | What it does |
| --- | --- |
| `test` | `pytest` on the API, no Docker needed |
| `docker/metadata-action` | Tags: `sha-<commit>` always, `latest` on main, `1.2.3` for a `v1.2.3` Git tag |
| `docker/build-push-action` + `cache-from/to: type=gha` | Builds both images and keeps their layers in the GitHub Actions cache |
| Smoke test | Starts the API image and calls `/health` and `/api/info` |
| Trivy | Fails the run on fixable HIGH or CRITICAL vulnerabilities (the security lab's gate) |
| `docker/login-action` + push | Logs in to `ghcr.io` with the built-in `GITHUB_TOKEN` (`permissions: packages: write`) and pushes. Skipped for pull requests |

### 2. Run it

```bash
git add .github/workflows/pipeline.yml
git commit -m "CI/CD pipeline: test, build, scan, push"
git push
gh run watch          # or open the Actions tab
```

The second run is faster: the build steps say `CACHED` for the dependency layers.

### 3. Find the images

On GitHub: your profile → **Packages** → `shopkart-api` and `shopkart-web` (private by default). In the terminal:

```bash
OWNER=$(echo "$GITHUB_USER" | tr '[:upper:]' '[:lower:]')
TAG=sha-$(git rev-parse --short=7 HEAD)
gh auth token | docker login ghcr.io -u "$GITHUB_USER" --password-stdin
docker pull ghcr.io/$OWNER/shopkart-api:$TAG
```

If the login or pull is refused, use a classic token with `read:packages` and `write:packages` saved as the Codespaces secret `GHCR_TOKEN` (see the registry lab): `echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin`.

## Part 2: deploy to a server

### 4. A key and a server

```bash
ssh-keygen -t ed25519 -N '' -f ~/.ssh/shopkart_deploy
docker build -t shopkart-server labs/ci-cd/server
docker run -d --privileged --name shopkart-server -p 2222:22 -p 8081:80 \
  -e AUTHORIZED_KEY="$(cat ~/.ssh/shopkart_deploy.pub)" shopkart-server
```

Tell SSH how to reach it, and check that the server's own Docker answers:

```bash
cat >> ~/.ssh/config <<'CFG'
Host shopkart-server
  HostName localhost
  Port 2222
  User deploy
  IdentityFile ~/.ssh/shopkart_deploy
  StrictHostKeyChecking accept-new
CFG
ssh shopkart-server docker version --format 'server engine {{.Server.Version}}'
```

### 5. A Docker context: "run my docker commands over there"

```bash
docker context create shopkart-server --docker host=ssh://shopkart-server
docker context ls
docker --context shopkart-server ps
```

`docker --context shopkart-server …` runs on the server, over SSH. No Docker port is opened on the network.

### 6. Deploy

`deploy/compose.yaml` uses only images from the registry (no `build:`, no files from the repo), and a `seed` job creates the products table before the API starts.

```bash
export IMAGE_PREFIX=ghcr.io/$OWNER
export TAG=sha-$(git rev-parse --short=7 HEAD)
docker --context shopkart-server compose -f labs/ci-cd/deploy/compose.yaml up -d --wait
docker --context shopkart-server compose -f labs/ci-cd/deploy/compose.yaml ps --format 'table {{.Service}}\t{{.Image}}\t{{.Status}}'
curl -s localhost:8081/api/info; echo
```

Port 8081 in the codespace is port 80 on the server (open it from the Ports tab to see the shop).
The pull goes from the server, using the login you made in step 3.

### 7. Roll out a new version

Make a visible change, push, and let the pipeline build it:

```bash
sed -i 's/Connecting to the API…/Loading the Diwali sale…/' app/web/index.html
git commit -am "Diwali sale copy" && git push
gh run watch
export TAG=sha-$(git rev-parse --short=7 HEAD)
docker --context shopkart-server compose -f labs/ci-cd/deploy/compose.yaml up -d --wait
curl -s localhost:8081/api/info; echo
```

Compose pulls the new images and recreates only `api`, `web` and the `seed` job. The database and its volume stay.

### 8. Roll back

Something wrong? Deploy the previous tag again:

```bash
export TAG=sha-<previous commit>
docker --context shopkart-server compose -f labs/ci-cd/deploy/compose.yaml up -d --wait
```

That's why every image gets an immutable `sha-` tag and not just `latest`.

### 9. Clean up

```bash
docker --context shopkart-server compose -f labs/ci-cd/deploy/compose.yaml down -v
docker context rm shopkart-server
docker rm -fv shopkart-server
```

Then delete the `Host shopkart-server` block from `~/.ssh/config`.

## From here to a real server

The same commands work against a real VM with Docker installed: change `HostName` and `Port` in `~/.ssh/config`. To deploy from the pipeline instead of your terminal, add a job that runs the same `docker compose up -d` over SSH, with the private key stored as an Actions secret. Beyond one server: a managed container service, or an orchestrator (Swarm, Kubernetes) when you need many servers and automatic rescheduling.

## Checkpoint

- [ ] The pipeline is green and both images are in your Packages
- [ ] `docker --context shopkart-server ps` lists the stack running on the server
- [ ] `/api/info` on port 8081 showed the new `sha-` version after step 7, and the old one after a rollback
