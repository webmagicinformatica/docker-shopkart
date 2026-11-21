#!/usr/bin/env bash
# Run ShopKart WITHOUT containers: Python on your machine, SQLite in memory, cart in memory.
# This is the "it works on my machine" version. Open http://localhost:8000
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d .venv ] || python3 -m venv .venv
.venv/bin/pip install --quiet --disable-pip-version-check -r app/api/requirements-dev.txt
cd app/api
WEB_DIR=../web exec ../../.venv/bin/uvicorn shopkart_api.main:app --host 0.0.0.0 --port 8000
