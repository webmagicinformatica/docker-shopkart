#!/usr/bin/env bash
# Run QuickBite WITHOUT containers: Node.js on your machine, orders in memory, and a fake
# kitchen inside the API instead of Redis + the Python worker. Open http://localhost:3000
# This is the "works on my machine" version that the capstone replaces.
set -euo pipefail
cd "$(dirname "$0")/api"
npm ci --no-audit --no-fund
WEB_DIR=../web exec node src/server.js
