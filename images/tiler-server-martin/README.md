# tiler-server-martin

Serves vector tiles from tiler-db with [Martin](https://github.com/maplibre/martin) on port 80. It is an alternative to `tiler-server` (Tegola). By default it publishes every table of the `public` schema, so each imposm table becomes a tile source. Put `tiler-varnish` in front of it to cache tiles.

| | |
|---|---|
| Base image | `ghcr.io/maplibre/martin:v0.14.2` |
| Chart values key | `tilerServerMartin` |
| Compose | `compose/tiler.yaml` service `tiler-server-martin` |
| Env files | `compose/envs/.env.tiler-db.example` |

```sh
cd compose && docker compose -f tiler.yaml up --build tiler-db tiler-server-martin tiler-varnish
```

- Sources: `http://localhost:9091/catalog`
- One table: `http://localhost:9091/{table}/{z}/{x}/{y}`
- Several tables in one tile: `http://localhost:9091/{table1},{table2}/{z}/{x}/{y}`
- Cached by Varnish: the same paths on `http://localhost:6081`

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | | tiler-db connection |
| `MARTIN_PORT` | `80` | Listen port |
| `MARTIN_WORKER_PROCESSES` | `8` | Martin workers |
| `MARTIN_POOL_SIZE` | `20` | Postgres connection pool |
| `MARTIN_SCHEMAS` | `public` | Schemas whose tables are published |
| `MARTIN_PUBLISH_FUNCTIONS` | `false` | Also publish SQL function sources |
| `MARTIN_DEFAULT_SRID` | `3857` | SRID for geometries without one |
| `MARTIN_CACHE_SIZE_MB` | `0` | Martin memory cache. Keep `0` when Varnish is in front |
| `MARTIN_CONFIG` | `/app/config/config.yaml` | Config path |

## Custom config

If a file exists at `MARTIN_CONFIG`, `start.sh` uses it and skips the generated config. Mount your own Martin config there, or build your own image and set `tilerServerMartin.image` to serve SQL functions or materialized views.
