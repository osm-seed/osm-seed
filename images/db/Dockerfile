# Stage 1: Compilar el plugin para PostgreSQL 17
FROM postgres:17 AS builder

# Instalar dependencias de compilación
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

# Clonar y compilar el plugin osmdbt para PostgreSQL 17
RUN git clone https://github.com/openstreetmap/osmdbt.git /tmp/osmdbt && \
    cd /tmp/osmdbt && \
    git checkout v0.9 && \
    cd postgresql-plugin && \
    mkdir -p build && cd build && \
    cmake .. && \
    make

FROM postgres:17

# pgBackRest: WAL archiving and base backups to S3 (webDb.pgbackrest)
ARG PGBACKREST_VERSION=2.59.1
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    "pgbackrest=${PGBACKREST_VERSION}-*" \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /tmp/osmdbt/postgresql-plugin/build/osm-logical.so /usr/lib/postgresql/17/lib/osm-logical.so

RUN ln -s /usr/lib/postgresql/17/lib/osm-logical.so /usr/lib/postgresql/17/lib/osm_logical.so

RUN chown postgres:postgres /usr/lib/postgresql/17/lib/osm-logical.so && \
    chown postgres:postgres /usr/lib/postgresql/17/lib/osm_logical.so && \
    chmod 755 /usr/lib/postgresql/17/lib/osm-logical.so && \
    chmod 755 /usr/lib/postgresql/17/lib/osm_logical.so
