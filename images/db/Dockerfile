FROM postgres:17 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    cmake \
    git \
    libboost-program-options-dev \
    libbz2-dev \
    libexpat1-dev \
    libosmium2-dev \
    libprotozero-dev \
    libyaml-cpp-dev \
    libpqxx-dev \
    postgresql-server-dev-17 \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Clone and build osmdbt plugin for PostgreSQL 17
RUN git clone https://github.com/openstreetmap/osmdbt.git /tmp/osmdbt && \
    cd /tmp/osmdbt && \
    git checkout v0.9 && \
    cd postgresql-plugin && \
    mkdir -p build && cd build && \
    cmake .. && \
    make

FROM postgres:17

RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-17-postgis-3 \
    postgresql-17-postgis-3-scripts \
    && rm -rf /var/lib/apt/lists/*

# pgBackRest: WAL archiving and base backups to S3 (webDb.pgbackrest)
ARG PGBACKREST_VERSION=2.59.1
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    "pgbackrest=${PGBACKREST_VERSION}-*" \
    && rm -rf /var/lib/apt/lists/*

# Auto-create required extensions on fresh initdb
COPY ./scripts/init-extensions.sh /docker-entrypoint-initdb.d/10-extensions.sh
RUN chmod +x /docker-entrypoint-initdb.d/10-extensions.sh

COPY --from=builder /tmp/osmdbt/postgresql-plugin/build/osm-logical.so /usr/lib/postgresql/17/lib/osm-logical.so

RUN ln -s /usr/lib/postgresql/17/lib/osm-logical.so /usr/lib/postgresql/17/lib/osm_logical.so

RUN chown postgres:postgres /usr/lib/postgresql/17/lib/osm-logical.so && \
    chown postgres:postgres /usr/lib/postgresql/17/lib/osm_logical.so && \
    chmod 755 /usr/lib/postgresql/17/lib/osm-logical.so && \
    chmod 755 /usr/lib/postgresql/17/lib/osm_logical.so
