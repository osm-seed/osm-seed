#!/usr/bin/env bash
set -euo pipefail

export MARTIN_PORT="${MARTIN_PORT:-80}"
MARTIN_CONFIG="${MARTIN_CONFIG:-/app/config/config.yaml}"

echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -p "${POSTGRES_PORT}" > /dev/null 2>&1; do
  sleep 1
done
echo "PostgreSQL is ready."

# A mounted config file wins. Otherwise publish every table of the imposm schema.
if [ -f "$MARTIN_CONFIG" ]; then
  echo "Using existing Martin config: $MARTIN_CONFIG"
else
  echo "Generating Martin config..."
  mkdir -p "$(dirname "$MARTIN_CONFIG")"
  cat > "$MARTIN_CONFIG" <<EOF
listen_addresses: '0.0.0.0:${MARTIN_PORT}'
worker_processes: ${MARTIN_WORKER_PROCESSES:-8}
# Varnish is the tile cache, so Martin always renders fresh tiles.
cache_size_mb: ${MARTIN_CACHE_SIZE_MB:-0}

postgres:
  connection_string: 'postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}?connect_timeout=10&keepalives=1&keepalives_idle=30'
  pool_size: ${MARTIN_POOL_SIZE:-20}
  default_srid: ${MARTIN_DEFAULT_SRID:-3857}
  auto_publish:
    tables:
      from_schemas: ${MARTIN_SCHEMAS:-public}
    functions: ${MARTIN_PUBLISH_FUNCTIONS:-false}
EOF
fi

echo "Starting Martin on port ${MARTIN_PORT}..."
exec martin --config "$MARTIN_CONFIG"
