# changeset-replication-job

Publishes changeset replication files with `replicate_changesets.rb`, a copy of the [script that OpenStreetMap runs](https://github.com/openstreetmap/chef/blob/master/cookbooks/planet/templates/default/replicate-changesets.erb), and uploads them to `replication/changesets` in S3. Each sequence has a `.osm.gz` and a `.state.txt` file. When there are no changesets to publish, the job writes and uploads nothing. State is recovered from S3 on restart.

| | |
|---|---|
| Base image | `ruby:3.4` |
| Chart values key | `changesetReplicationJob` |
| Compose | `compose/planet.yaml` service `changeset-replication-job` |
| Env files | `compose/envs/.env.db.example`, `compose/envs/.env.cloudprovider.example` |

The header of each file takes `copyright`, `attribution` and `license` from the env vars `COPYRIGHT_OWNER`, `ATTRIBUTION_URL` and `LICENSE_URL`. Without them, it uses the OpenStreetMap values.

```sh
cd compose && docker compose -f planet.yaml build changeset-replication-job && docker compose -f planet.yaml up changeset-replication-job
```
