# Lab: containerize the ShopKart API.
# Build from the repo root:  docker build -f labs/dockerfile/start/Dockerfile -t shopkart-api:1.0 app/api

# TODO 1: start FROM the official Python 3.12 slim image (pin the tag: python:3.12.16-slim-trixie)

# TODO 2: set the working directory to /app

# TODO 3: copy the app's files into the image

# TODO 4: install the Python packages listed in requirements.txt

# TODO 5: the default command: run uvicorn on 0.0.0.0, port 8000
#         uvicorn shopkart_api.main:app --host 0.0.0.0 --port 8000

# ---- Part 2 ----
# TODO 6: copy requirements.txt and install it BEFORE copying the rest, so code edits don't re-run pip
# TODO 7: add a Dockerfile.dockerignore next to this file (tests, caches, .env stay out of the image)
# TODO 8: ARG APP_VERSION (default "dev") passed into ENV APP_VERSION
# TODO 9: EXPOSE 8000 and a HEALTHCHECK that calls http://127.0.0.1:8000/health
# TODO 10: ENTRYPOINT for the program, CMD for its default arguments
