# ShopKart web: nginx with the static site and the /api proxy baked in.
# Build from the repo root: docker build -f app/web/Dockerfile -t shopkart-web app
FROM nginx:1.30.7-alpine
RUN apk upgrade --no-cache
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY web/index.html web/app.js web/style.css /usr/share/nginx/html/
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
