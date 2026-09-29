FROM ghcr.io/maplibre/martin:v0.14.2

USER root

RUN apk add --no-cache \
    bash \
    curl \
    postgresql-client

WORKDIR /app
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

ENTRYPOINT ["/bin/bash"]
CMD ["/app/start.sh"]
