### Unreleased

- Add the `tiler-server-martin` image: a generic Martin server that publishes the imposm tables as tile sources. It is built by chartpress and fills `tilerServerMartin.image`.
- Add Martin and Varnish to `compose/tiler.yaml`. `tilerVarnish.image` now defaults to `varnish:7.5`.
- Remove the OHM-only variables `OHM_DOMAIN` and `AWS_*` from `tilerServerMartin.env`.

### v2.0.0

Breaking changes. Upgrading in place from an older release is not supported. Install a new release and migrate data.

- Resources are named `<release>-<component>` with no kind suffix. `web` and `db` are now `web-api` and `web-db`, with values keys `webApi` and `webDb`. Services use the same name as their workload. PV and PVC share the name `<release>-<component>-data`.
- `Chart.yaml` moves to apiVersion v2. The chart now requires Helm 3 and Kubernetes 1.25 or newer.
- OHM-specific defaults are replaced with neutral values. Around 70 missing keys were added to `values.yaml` so `helm template` works with defaults.
- Repeated template blocks (resources, nodeSelector, affinity, labels, service account, image) move into helpers in `_helpers.tpl`.
- The local Docker Compose setup moves under `compose/`. Image READMEs are shortened.
- The default branch is renamed from `develop` to `main`. The chart and images are published on every push to `main` and on tags.

### v0.1.1

Fix silly bugs with labels that was preventing a deploy, minor documentation improvements
