# Part 2: fast rebuilds, a version label and a health check.
FROM python:3.12.16-slim-trixie

# Build-time input (ARG) -> kept at run time (ENV)
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Dependencies first: this layer is reused until requirements.txt changes
COPY requirements.txt .
RUN pip install -r requirements.txt

# Then the code, which changes all the time
COPY . .

EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

# ENTRYPOINT = the program, CMD = default arguments you can override at `docker run`
ENTRYPOINT ["uvicorn", "shopkart_api.main:app"]
CMD ["--host", "0.0.0.0", "--port", "8000"]
