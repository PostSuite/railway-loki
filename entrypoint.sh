#!/bin/sh
set -e

# Default port if Railway doesn't set one
PORT="${PORT:-8080}"
export PORT

# Require AUTH_TOKEN to be set
if [ -z "$AUTH_TOKEN" ]; then
  echo "ERROR: AUTH_TOKEN environment variable must be set"
  exit 1
fi

# Render nginx config with env vars
envsubst '${PORT} ${AUTH_TOKEN}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Strip the protocol scheme from S3_ENDPOINT. Railway populates the bucket
# variable as a full URL (e.g. `https://t3.storageapi.dev`) but Loki's S3
# client wants a hostname only — HTTPS is controlled separately by
# `insecure: false` in loki-config.yaml. Doing it here lets the Railway
# env var stay as a clean `${{"Loki Bucket".ENDPOINT}}` reference.
if [ -n "$S3_ENDPOINT" ]; then
  S3_ENDPOINT="${S3_ENDPOINT#https://}"
  S3_ENDPOINT="${S3_ENDPOINT#http://}"
  export S3_ENDPOINT
fi

# Start Loki in the background.
# `-config.expand-env=true` lets the YAML reference Railway env vars via
# `${VAR}` syntax (used for the S3 credentials/endpoint/bucket).
/usr/bin/loki -config.file=/etc/loki/loki-config.yaml -config.expand-env=true &

# Wait for Loki to be ready
echo "Waiting for Loki to start..."
for i in $(seq 1 30); do
  if wget -q -O /dev/null http://127.0.0.1:3100/ready 2>/dev/null; then
    echo "Loki is ready"
    break
  fi
  sleep 1
done

# Start nginx in the foreground
echo "Starting nginx on port $PORT"
exec nginx -g 'daemon off;'
