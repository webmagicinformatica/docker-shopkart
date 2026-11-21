# syntax=docker/dockerfile:1
# Step 2: multi-stage on Alpine. The build stage installs into a virtualenv; the final stage
# copies only that venv and the code. A BuildKit cache mount keeps pip's downloads between builds.

FROM python:3.12.16-alpine3.24 AS build
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
RUN python -m venv /venv
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    /venv/bin/pip install -r requirements.txt

FROM python:3.12.16-alpine3.24
ENV PATH=/venv/bin:$PATH PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY --from=build /venv /venv
COPY . .
CMD ["uvicorn", "shopkart_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
