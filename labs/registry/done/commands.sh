#!/usr/bin/env bash
# Sharing images: a local registry, a clean machine, and GitHub Container Registry.
# Run the blocks one at a time. Needs the shopkart-api:1.1 image from the Dockerfile lab:
#   docker build -f labs/dockerfile/done/part2/Dockerfile --build-arg APP_VERSION=1.1 -t shopkart-api:1.1 app/api

# --- A. Your own registry (registry:2) ---
docker network create shipping
docker run -d --name registry --network shipping -p 5000:5000 -v registry-data:/var/lib/registry registry:2.8.3

docker tag shopkart-api:1.1 localhost:5000/shopkart-api:1.1
docker push localhost:5000/shopkart-api:1.1
curl -s localhost:5000/v2/_catalog
curl -s localhost:5000/v2/shopkart-api/tags/list

# The digest: the image's real, unchangeable ID
docker buildx imagetools inspect localhost:5000/shopkart-api:1.1 | head -n 4

# --- B. The latest trap: "latest" is just a tag, and it moves ---
docker tag shopkart-api:1.1 localhost:5000/shopkart-api:latest
docker push localhost:5000/shopkart-api:latest
curl -s localhost:5000/v2/shopkart-api/tags/list

# --- C. A clean machine: a brand-new Docker engine with no images at all ---
docker run -d --privileged --name clean-machine --network shipping docker:29.10.0-dind --insecure-registry registry:5000
sleep 8
docker exec clean-machine docker images
DIGEST=$(docker buildx imagetools inspect localhost:5000/shopkart-api:1.1 --format '{{json .Manifest.Digest}}' | tr -d '"')
docker exec clean-machine docker run -d --name api -p 8000:8000 "registry:5000/shopkart-api@$DIGEST"
sleep 5
docker exec clean-machine wget -qO- localhost:8000/api/info; echo

# --- D. GitHub Container Registry (ghcr.io) ---
OWNER=$(echo "$GITHUB_USER" | tr '[:upper:]' '[:lower:]')        # ghcr.io names must be lowercase
gh auth token | docker login ghcr.io -u "$GITHUB_USER" --password-stdin
docker tag shopkart-api:1.1 "ghcr.io/$OWNER/shopkart-api:1.1"
docker push "ghcr.io/$OWNER/shopkart-api:1.1"
docker logout ghcr.io

# --- Clean up ---
docker rm -fv clean-machine registry
docker volume rm registry-data
docker network rm shipping
docker rmi localhost:5000/shopkart-api:1.1 localhost:5000/shopkart-api:latest
