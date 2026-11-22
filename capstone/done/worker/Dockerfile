# syntax=docker/dockerfile:1
# QuickBite worker: dependencies built in a virtualenv, tests in their own stage, a non-root
# user and a health check that reads the worker's heartbeat file.

# ---- build: install the dependencies into /venv ----
FROM python:3.12.16-alpine3.24 AS build
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_ROOT_USER_ACTION=ignore
RUN python -m venv /venv
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip /venv/bin/pip install -r requirements.txt

# ---- test: docker build --target test . (fails the build if a test fails) ----
FROM build AS test
WORKDIR /app
COPY requirements.txt requirements-dev.txt ./
RUN --mount=type=cache,target=/root/.cache/pip /venv/bin/pip install -r requirements-dev.txt
COPY . .
RUN /venv/bin/python -m pytest -q -p no:cacheprovider

# ---- runtime: python, the venv and the code ----
FROM python:3.12.16-alpine3.24 AS runtime
ENV PATH=/venv/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HEARTBEAT_FILE=/tmp/quickbite-worker.heartbeat
# Patch the OS packages, remove pip (not needed at run time), add an unprivileged user
RUN apk upgrade --no-cache \
 && python -m pip uninstall -y pip \
 && adduser -S -u 10001 -H worker
WORKDIR /app
COPY --from=build /venv /venv
COPY quickbite_worker ./quickbite_worker
USER 10001
# Healthy = the heartbeat file was touched in the last 20 seconds (it is touched every 5 or less)
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import os, sys, time; sys.exit(0 if time.time() - os.path.getmtime(os.environ['HEARTBEAT_FILE']) < 20 else 1)"]
CMD ["python", "-m", "quickbite_worker.main"]
