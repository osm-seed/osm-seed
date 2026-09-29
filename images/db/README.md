# db

PostgreSQL 17 for the website and API, with the `openstreetmap-website` SQL functions and the [osmdbt](https://github.com/openstreetmap/osmdbt) `osm-logical` plugin (v0.9) for logical replication.

| | |
|---|---|
| Base image | `postgres:17` |
| Chart values key | `webDb` |
| Compose | `compose/web.yaml` service `db` |
| Env files | `compose/envs/.env.db.example` |

- Includes [pgBackRest](https://pgbackrest.org) for WAL archiving and base backups to S3 (`webDb.pgbackrest` in the chart).
- PostgreSQL 17.11+ only accepts whitelisted output plugins: set `output_plugin_libraries = 'pgoutput, test_decoding, osm-logical'` in `postgresql.conf` (see `webDb.postgresqlConfig.values` in the chart).

```sh
cd compose && docker compose -f web.yaml build db && docker compose -f web.yaml up db
```
