#!/usr/bin/env bash
# Your first containers. Fill in each TODO, then run the lines one by one in the terminal.

# 0. Before containers: run ShopKart straight on Python (Ctrl+C to stop)
./scripts/run-local.sh

# 1. Is Docker here? Print the client and the server (engine) versions
# TODO: docker ...

# 2. Run the hello-world image
# TODO: docker ...

# 3. Run nginx 1.30.7-alpine in the background, named "web", port 8080 on your machine -> port 80 in the container
# TODO: docker run ...

# 4. List running containers, then fetch the page
# TODO: docker ...
curl -s localhost:8080 | head -n 4

# 5. Read nginx's logs
# TODO: docker ...

# 6. Stop and remove the container
# TODO: docker ...
