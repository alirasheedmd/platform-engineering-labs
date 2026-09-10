FROM nginx:1.27-alpine

COPY index.html /usr/share/nginx/html/index.html

HEALTHCHECK \
  --interval=10s \
  --timeout=3s \
  --start-period=5s \
  --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
