# Lab: Tag, push and pull ShopKart

Push the ShopKart API image to a registry you run yourself (`registry:2`), pull it **by digest** on a brand-new Docker engine ("a clean machine"), then push it to **GitHub Container Registry** (ghcr.io).

Commands: `start/commands.sh` (TODOs) and `done/commands.sh`. Run them block by block.
You need the `shopkart-api:1.1` image from the Dockerfile lab. Don't have it?

```bash
docker build -f labs/dockerfile/done/part2/Dockerfile --build-arg APP_VERSION=1.1 -t shopkart-api:1.1 app/api
```

## A. Your own registry

```bash
docker network create shipping
docker run -d --name registry --network shipping -p 5000:5000 -v registry-data:/var/lib/registry registry:2.8.3
docker tag shopkart-api:1.1 localhost:5000/shopkart-api:1.1
docker push localhost:5000/shopkart-api:1.1
curl -s localhost:5000/v2/_catalog
curl -s localhost:5000/v2/shopkart-api/tags/list
docker buildx imagetools inspect localhost:5000/shopkart-api:1.1 | head -n 4
```

An image name is `registry/repository:tag`. With no registry in front (`nginx`), Docker means Docker Hub.
The **digest** (`sha256:…`) is the image's real ID: a tag can be moved to another image, a digest can't.

## B. The `latest` trap

```bash
docker tag shopkart-api:1.1 localhost:5000/shopkart-api:latest
docker push localhost:5000/shopkart-api:latest
curl -s localhost:5000/v2/shopkart-api/tags/list
```

`latest` is just a tag name, not "the newest". It points wherever the last push put it. Deploy with a version tag or a digest.

## C. A clean machine

`docker:dind` is a whole Docker engine in a container, with no images at all. We start one on the same network as the registry:

```bash
docker run -d --privileged --name clean-machine --network shipping docker:29.10.0-dind --insecure-registry registry:5000
sleep 8
docker exec clean-machine docker images
DIGEST=$(docker buildx imagetools inspect localhost:5000/shopkart-api:1.1 --format '{{json .Manifest.Digest}}' | tr -d '"'); echo $DIGEST
docker exec clean-machine docker run -d --name api -p 8000:8000 "registry:5000/shopkart-api@$DIGEST"
docker exec clean-machine wget -qO- localhost:8000/api/info; echo
```

`--insecure-registry` is only because our practice registry speaks plain HTTP. Real registries use HTTPS.

## D. GitHub Container Registry

In a codespace, `$GITHUB_USER` is your GitHub username and `gh` is already signed in.

```bash
OWNER=$(echo "$GITHUB_USER" | tr '[:upper:]' '[:lower:]')        # ghcr.io names must be lowercase
gh auth token | docker login ghcr.io -u "$GITHUB_USER" --password-stdin
docker tag shopkart-api:1.1 "ghcr.io/$OWNER/shopkart-api:1.1"
docker push "ghcr.io/$OWNER/shopkart-api:1.1"
docker logout ghcr.io
```

Then open **github.com → your profile → Packages**: `shopkart-api` is there, **private** by default.

If the push says `denied` or `permission_denied`, the codespace's token can't write packages for your account. Create a **classic** personal access token with only the `write:packages` scope (github.com/settings/tokens), save it as a Codespaces secret named `GHCR_TOKEN`, reload the codespace, and log in with it:

```bash
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin
```

> **Docker Hub (optional, needs a free account):** `docker login`, then `docker tag shopkart-api:1.1 <your-hub-user>/shopkart-api:1.1` and `docker push <your-hub-user>/shopkart-api:1.1`. Anonymous pulls from Docker Hub are rate-limited, which is one more reason to log in on build machines.

## Clean up

```bash
docker rm -fv clean-machine registry
docker volume rm registry-data
docker network rm shipping
docker rmi localhost:5000/shopkart-api:1.1 localhost:5000/shopkart-api:latest
```

## Checkpoint

- [ ] `tags/list` shows `1.1` and `latest`
- [ ] The clean machine ran the API pulled **by digest**
- [ ] `shopkart-api` appears under your GitHub Packages
