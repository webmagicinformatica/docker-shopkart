# syntax=docker/dockerfile:1
# ShopKart API, scanned and fixed: patched OS packages, a non-root user, a health check.
# (Same as app/api/Dockerfile.)

# ---- build stage: install dependencies into a virtualenv ----
FROM python:3.12.16-alpine3.24 AS build
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
RUN python -m venv /venv
COPY requirements.txt .
RUN /venv/bin/pip install -r requirements.txt

# ---- runtime stage: only the venv and the app ----
FROM python:3.12.16-alpine3.24
ARG APP_VERSION=dev
ENV PATH=/venv/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=$APP_VERSION
# Patch the OS packages, then add an unprivileged user
RUN apk upgrade --no-cache && adduser -S -u 10001 -H shopkart
WORKDIR /app
COPY --from=build /venv /venv
COPY --chown=root:root . .
USER 10001
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]
CMD ["uvicorn", "shopkart_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
