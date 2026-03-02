FROM grafana/loki:latest

USER root

# Install nginx and envsubst
RUN apk add --no-cache nginx gettext

# Copy configs
COPY loki-config.yaml /etc/loki/loki-config.yaml
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Railway provides $PORT — nginx listens there, proxies to Loki on 3100
EXPOSE 3100

ENTRYPOINT ["/entrypoint.sh"]
