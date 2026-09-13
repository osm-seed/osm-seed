# Run osm-seed locally with Docker Compose

This folder runs the osm-seed containers on one machine. Use it to develop or test an
image without a Kubernetes cluster. To deploy on Kubernetes use the Helm chart in
[`../osm-seed`](../osm-seed/README.md).

## Setup

```sh
cd compose
./envs/envs.sh          # creates envs/.env.* from the .example files
```

Edit the `envs/.env.*` files you need. They are ignored by git.

## Run

Each file starts one group of containers. `web.yaml` runs the website, the API and its
database:

```sh
docker compose -f web.yaml up
```

Combine files to run more services together:

```sh
docker compose -f web.yaml -f populate-apidb.yaml up   # website + import a PBF
docker compose -f web.yaml -f cgimap.yaml up            # website + cgimap
```

| File | Services | Ports |
|---|---|---|
| `web.yaml` | db, web, memcache | web `80` |
| `cgimap.yaml` | cgimap | `80` |
| `populate-apidb.yaml` | populate-apidb | |
| `db-backup-restore.yaml` | db-backup-restore | |
| `planet.yaml` | osm-processor, replication-job, planet-dump, full-history, changesets-dump, changeset-replication-job, planet-files | planet-files `8081`, `8082` |
| `osm-simple-metrics.yaml` | osm-simple-metrics | |
| `tiler.yaml` | tiler-db, tiler-server | tiler-db `5432`, tiles `9090` |
| `nominatim.yaml` | nominatim-api | `8080` |
| `overpass.yaml` | overpass-api | `8081` |
| `taginfo.yaml` | taginfo_data, taginfo_web | `4567` |
| `tasking-manager.yaml` | tmdb, migration, tmapi | `5000` |
| `osmcha.yaml` | django, frontend, redis | `5001`, `8000`, `6379` |

Container data is written to `data/` (ignored by git).

## Build an image

Every file builds its images from `../images/<name>`. To rebuild one after editing its
Dockerfile or scripts:

```sh
docker compose -f tiler.yaml build tiler-imposm
docker compose -f tiler.yaml up tiler-imposm
```

Images are published to `ghcr.io/osm-seed/<name>` by chartpress on every push to
`main`; nothing here is used by that pipeline.
