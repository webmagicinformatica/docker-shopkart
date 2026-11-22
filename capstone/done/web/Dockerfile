# syntax=docker/dockerfile:1
# QuickBite web: static files on an unprivileged nginx (runs as user 101, listens on 8080).
# No build step, so one stage is enough.
FROM nginxinc/nginx-unprivileged:1.31.7-alpine3.24
# Patching needs root for a moment, then back to the nginx user
USER root
RUN apk upgrade --no-cache
USER 101
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html app.js style.css /usr/share/nginx/html/
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["wget", "-q", "-O", "/dev/null", "http://127.0.0.1:8080/health"]
