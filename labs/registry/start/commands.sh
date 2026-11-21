#!/usr/bin/env bash
# Sharing images. Fill in the TODOs, then run the blocks one at a time.

# --- A. Your own registry (registry:2) ---
docker network create shipping
docker run -d --name registry --network shipping -p 5000:5000 -v registry-data:/var/lib/registry registry:2.8.3
# TODO: tag shopkart-api:1.1 as localhost:5000/shopkart-api:1.1
# TODO: push it
curl -s localhost:5000/v2/_catalog
curl -s localhost:5000/v2/shopkart-api/tags/list
# TODO: show its digest with docker buildx imagetools inspect

# --- B. The latest trap ---
# TODO: tag and push the same image as :latest, then list the tags again

# --- C. A clean machine ---
docker run -d --privileged --name clean-machine --network shipping docker:29.10.0-dind --insecure-registry registry:5000
sleep 8
docker exec clean-machine docker images
# TODO: on clean-machine, run registry:5000/shopkart-api pinned BY DIGEST, port 8000
docker exec clean-machine wget -qO- localhost:8000/api/info; echo

# --- D. GitHub Container Registry ---
OWNER=$(echo "$GITHUB_USER" | tr '[:upper:]' '[:lower:]')
# TODO: docker login ghcr.io with your token (gh auth token | docker login ...)
# TODO: tag as ghcr.io/$OWNER/shopkart-api:1.1 and push

# --- Clean up ---
docker rm -fv clean-machine registry
docker volume rm registry-data
docker network rm shipping
