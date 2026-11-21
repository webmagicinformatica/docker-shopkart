# syntax=docker/dockerfile:1
# The small image from the slim-image lab. Scan it, then fix what the scanner finds.
FROM python:3.12.16-alpine3.24 AS build
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
RUN python -m venv /venv
COPY requirements.txt .
RUN /venv/bin/pip install -r requirements.txt

FROM python:3.12.16-alpine3.24
ENV PATH=/venv/bin:$PATH PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
# TODO: upgrade the OS packages (apk upgrade --no-cache) so the fixed versions are installed
# TODO: create an unprivileged user with uid 10001 (adduser -S -u 10001 -H shopkart)
WORKDIR /app
COPY --from=build /venv /venv
COPY . .
# TODO: switch to that user (USER 10001)
EXPOSE 8000
CMD ["uvicorn", "shopkart_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
