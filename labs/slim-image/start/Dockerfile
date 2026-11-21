# syntax=docker/dockerfile:1
# Shrink ShopKart: multi-stage on Alpine. Fill in the TODOs.

# ---- build stage ----
# TODO: FROM python:3.12.16-alpine3.24 AS build
# TODO: create a virtualenv in /venv
# TODO: copy requirements.txt and install it into /venv
#       with a pip cache mount: RUN --mount=type=cache,target=/root/.cache/pip ...

# ---- final stage ----
# TODO: FROM python:3.12.16-alpine3.24 (fresh: no pip cache, no build leftovers)
# TODO: put /venv/bin first on PATH
# TODO: WORKDIR /app, copy /venv from the build stage, then copy the code
CMD ["uvicorn", "shopkart_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
