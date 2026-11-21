#!/usr/bin/env bash
# Your first containers: the finished commands.

# 0. Before containers: run ShopKart straight on Python (Ctrl+C to stop)
./scripts/run-local.sh

# 1. Is Docker here? Print the client and the server (engine) versions
docker version

# 2. Run the hello-world image
docker run hello-world

# 3. Run nginx in the background, named "web", port 8080 on your machine -> port 80 in the container
docker run -d --name web -p 8080:80 nginx:1.30.7-alpine

# 4. List running containers, then fetch the page
docker ps
curl -s localhost:8080 | head -n 4

# 5. Read nginx's logs
docker logs web

# 6. Stop and remove the container
docker stop web
docker rm web
