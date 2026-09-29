# osm-seed Helm chart

Runs an OpenStreetMap-style stack on Kubernetes: website and API, database with backups,
replication and planet dumps, vector tiles, Nominatim, Overpass, Taginfo, Tasking Manager,
OSMCha, Level0 and monitoring. Every component is off by default; turn on what you need.

## Requirements

- Kubernetes 1.25 or newer
- Helm 3
- An ingress controller (ingress-nginx, Traefik) if you expose services with `ingress.enabled`
- cert-manager if you want the chart to create a Let's Encrypt `ClusterIssuer` (`createClusterIssuer: true`)

## Install

```sh
helm repo add osm-seed https://osm-seed.github.io/osm-seed-chart
helm repo update
helm install osm osm-seed/osm-seed -f myvalues.yaml
```

Minimal `myvalues.yaml` to run the website and API with a database:

```yaml
cloudProvider: k3s   # aws or k3s

webDb:
  enabled: true
  persistenceDisk:
    enabled: true
webApi:
  enabled: true
  ingress:
    enabled: true
    hosts:
      - www.example.org
memcached:
  enabled: true
cgimap:
  enabled: true
```

Upgrade and remove:

```sh
helm upgrade osm osm-seed/osm-seed -f myvalues.yaml
helm uninstall osm
```

Resources are named `<release>-<component>`, for example `osm-web-api`, `osm-web-db`.
Services use the same name as their workload.

## Components

| Values key | Resource | What it does |
|---|---|---|
| `webDb` | `web-db` (StatefulSet) | PostgreSQL for the website and API (apidb) |
| `webApi` | `web-api` (Deployment) | openstreetmap-website: website + API 0.6 |
| `memcached` | `memcached` | Session cache for the website |
| `cgimap` | `cgimap` | C++ implementation of the read-only API calls |
| `populateApidb` | `populate-apidb` (Job) | Import a PBF into the apidb |
| `replicationJob` | `replication-job` | Publish minute/hour/day diffs to S3 |
| `changesetReplicationJob` | `changeset-replication-job` | Publish changeset diffs to S3 |
| `planetDump` | `planet-dump` (CronJob) | Planet PBF export |
| `fullHistory` | `full-history` (CronJob) | Full-history planet export |
| `changesetsDump` | `changesets-dump` (CronJob) | Changesets dump export |
| `dbBackupRestore` | `<db>-backup` (CronJob) | pg_dump to S3 / restore from S3 for web-db, tm-db, osmcha-db |
| `osmProcessor` | `osm-processor` (Job) | One-off PBF processing |
| `osmSimpleMetrics` | `osm-simple-metrics` (CronJob) | Basic edit metrics |
| `monitoringReplication` | `replication-monitoring` (CronJob) | Checks the replication stream |
| `tilerDb` | `tiler-db` (StatefulSet) | PostGIS for vector tiles |
| `tilerImposm` | `tiler-imposm` (StatefulSet) | imposm3 import and updates into tiler-db |
| `tilerServer` | `tiler-server` | Tegola vector tile server |
| `tilerServerMartin` | `tiler-server-martin` | Martin vector tile server |
| `tilerVarnish` | `tiler-varnish` | HTTP cache in front of the tile server |
| `tilerCache` | `tiler-cache` | Tile cache purge and seed (SQS) |
| `tilerMonitorPipeline` | `tiler-monitor-pipeline` | Checks that edits reach the tiles |
| `tilerMonitorLanguage` | `tiler-monitor-language` (CronJob) | Rebuilds language views when new languages appear |
| `osmxAdiffBuilder` | `osmx-adiff-builder` (StatefulSet) | Augmented diffs from OSMX to S3 |
| `planetStats` | `planet-stats` (CronJob) | Daily statistics from the planet file |
| `nominatimApi` | `nominatim-api` (StatefulSet) | Nominatim geocoder |
| `nominatimUI` | `nominatim-ui` | Nominatim web UI (image only) |
| `overpassApi` | `overpass-api` (StatefulSet) | Overpass API |
| `taginfoWeb` | `taginfo-web` | Taginfo website |
| `taginfoDataProcessor` | `taginfo-data-processor` (CronJob) | Builds the Taginfo databases |
| `tmDb` | `tm-db` (StatefulSet) | PostgreSQL for Tasking Manager |
| `tmApi` | `tm-api` | Tasking Manager API |
| `osmchaDb` | `osmcha-db` (StatefulSet) | PostgreSQL for OSMCha |
| `osmchaApi` | `osmcha-api` | OSMCha API and frontend |
| `osmchaWeb` | part of `osmcha-api` | OSMCha frontend image |
| `level0` | `level0` | Level0 editor |

Each component has the same shape in `values.yaml`: `enabled`, `image`, `env`,
`resources`, `nodeSelector`, `nodeAffinity`, and where it applies `persistenceDisk`,
`ingress`, `serviceAccount`, `autoscaling`, `schedule`. See
[values.yaml](values.yaml) for every key and its default.

## Cloud provider and storage

`cloudProvider` is `aws` or `k3s`.

- `aws`: persistent components use a static EBS volume. Set
  `persistenceDisk.AWS_ElasticBlockStore_volumeID` and `AWS_ElasticBlockStore_size`.
  Jobs upload to `AWS_S3_BUCKET`.
- `k3s`: with `persistenceDisk.staticHostPath: true` the chart creates a hostPath PV at
  `localVolumeHostPath` (data survives reinstalls). With `false` it uses the `local-path`
  storage class (dynamic, data is tied to the PVC).

PVCs are kept on `helm uninstall` (`helm.sh/resource-policy: keep`). Delete them by hand.

## Run a single job

Render one template and apply it, for example to import data once:

```sh
helm template osm osm-seed/osm-seed -f myvalues.yaml \
  --set populateApidb.enabled=true \
  --show-only templates/populate-apidb/populate-apidb-job.yaml | kubectl apply -f -
```

## Development

Chart and images are published from this repo with
[chartpress](https://github.com/jupyterhub/chartpress) on every push to `main`.
Image tags in `values.yaml` are filled at publish time.

Lint and render locally:

```sh
helm lint osm-seed
helm template test osm-seed -f myvalues.yaml
```
