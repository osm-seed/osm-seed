#!/bin/sh
set -e

psql --username="$POSTGRES_USER" --dbname="$POSTGRES_DB" -v ON_ERROR_STOP=1 <<-'EOSQL'
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS hstore;
    CREATE EXTENSION IF NOT EXISTS btree_gist;
EOSQL
