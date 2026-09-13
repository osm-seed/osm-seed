<p align="center">
  <img src="docs/img/osm-seed.png" alt="osm-seed" width="260">
</p>

<h1 align="center">osm-seed</h1>

<p align="center">Docker images and a Helm chart to run your own OpenStreetMap software stack</p>

<p align="center">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
</p>

OpenStreetMap runs open source software to manage geospatial data for the whole planet,
with an ecosystem of tools to edit, export and process it. Sometimes you need that stack
for data that cannot live in OpenStreetMap itself, because of its license or its scope.
osm-seed packages the OSM software so you can install and run your own instance, and it
uses the upstream code as is: changes go upstream, not into a fork.

## Components

Each component is a Docker image in [`images/`](images/) and a set of resources in the
Helm chart. Every image folder has a short README.

| Image | What it does |
|---|---|
| [`web`](images/web) | openstreetmap-website: the website and API 0.6 |
| [`db`](images/db) | PostgreSQL 17 for the API database, with the osmdbt replication plugin |
| [`cgimap`](images/cgimap) | C++ implementation of the read-heavy API calls |
| [`populate-apidb`](images/populate-apidb) | Import a PBF or OSM file into the API database |
| [`replication-job`](images/replication-job) | Publish minute diffs to S3 |
| [`changeset-replication-job`](images/changeset-replication-job) | Publish changeset diffs to S3 |
| [`planet-dump`](images/planet-dump), [`full-history`](images/full-history), [`changesets-dump`](images/changesets-dump) | Planet, full-history and changesets exports (built on [`osm-processor`](images/osm-processor)) |
| [`planet-files`](images/planet-files) | Web page that serves the planet and replication files |
| [`backup-restore`](images/backup-restore) | Database backups to S3 and restores |
| [`osm-simple-metrics`](images/osm-simple-metrics) | Basic edit metrics |
| [`tiler-db`](images/tiler-db), [`tiler-imposm`](images/tiler-imposm), [`tiler-server`](images/tiler-server) | Vector tiles: PostGIS, imposm3 import and updates, Tegola |
| [`nominatim`](images/nominatim) | [Nominatim](https://nominatim.org/) geocoder |
| [`overpass-api`](images/overpass-api) | [Overpass API](https://wiki.openstreetmap.org/wiki/Overpass_API) |
| [`taginfo`](images/taginfo), [`taginfo-web`](images/taginfo-web) | [Taginfo](https://wiki.openstreetmap.org/wiki/Taginfo) databases and website |
| [`tasking-manager-api`](images/tasking-manager-api) | [HOT Tasking Manager](https://github.com/hotosm/tasking-manager) backend |
| [`osmcha-db`](images/osmcha-db), [`osmcha-web`](images/osmcha-web) | [OSMCha](https://osmcha.org/) database and frontend |
| [`level0`](images/level0) | [Level0](https://github.com/Zverik/Level0) text editor |

Images are published to `ghcr.io/osm-seed/<name>` on every push to `main` and on tags.

## Run it

**On Kubernetes with Helm** (recommended): the chart in [`osm-seed/`](osm-seed/) deploys
any set of components. See [osm-seed/README.md](osm-seed/README.md).

```sh
helm repo add osm-seed https://osm-seed.github.io/osm-seed-chart
helm install osm osm-seed/osm-seed -f myvalues.yaml
```

**Locally with Docker Compose**, to develop or test single images. See
[compose/README.md](compose/README.md).

```sh
cd compose
./envs/envs.sh
docker compose -f web.yaml up
```

If you load data from OpenStreetMap into your instance, follow
[the ODbL license](https://wiki.osmfoundation.org/wiki/Licence).

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md).

## Credits and license

osm-seed was born at [Development Seed](https://developmentseed.org/) in 2018
([developmentseed/osm-seed](https://github.com/developmentseed/osm-seed)), where it was
built and maintained until 2025. Since January 2026 it lives in its own organization,
maintained by [Ruben Lopez](https://github.com/Rub21) ([GeoCompas](https://geocompas.org))
MIT License, see [LICENSE.txt](LICENSE.txt).
