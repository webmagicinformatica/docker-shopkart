# syntax=docker/dockerfile:1
# QuickBite API: production dependencies only, tests run in their own stage, no npm in the
# final image, a non-root user and a health check.

# ---- deps: production node_modules, from the lock file ----
FROM node:24.22.3-alpine3.24 AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev --no-audit --no-fund

# ---- test: docker build --target test . (fails the build if a test fails) ----
FROM deps AS test
COPY . .
RUN npm test

# ---- runtime: plain Alpine + the node binary + the dependencies and the code ----
# Copying just the node binary leaves npm, npx, corepack and yarn behind: the app never needs
# them at run time, and they hold most of the node image's size and CVEs.
FROM alpine:3.24.4 AS runtime
ARG APP_VERSION=dev
ENV NODE_ENV=production \
    APP_VERSION=$APP_VERSION
# node needs the C++ runtime; patch the OS packages; add an unprivileged user
RUN apk upgrade --no-cache \
 && apk add --no-cache libstdc++ \
 && adduser -S -u 10001 -H api
COPY --from=deps /usr/local/bin/node /usr/local/bin/node
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
USER 10001
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:3000/health').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"]
CMD ["node", "src/server.js"]
