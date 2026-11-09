# MapRoulette API

Docker image for the [MapRoulette backend](https://github.com/maproulette/maproulette-backend), based on [maproulette2-docker](https://github.com/maproulette/maproulette2-docker).

Build a different version with `--build-arg VERSION=<tag>`. Keep it compatible with the `maproulette-web` version.

Main env vars (full list in `conf/application.conf` of the backend):

| Env var | Description |
|---|---|
| `MR_DATABASE_URL` | `jdbc:postgresql://<host>:5432/<db>` |
| `MR_DATABASE_USERNAME` / `MR_DATABASE_PASSWORD` | DB credentials |
| `MR_OSM_SERVER` | OSM website URL, used for OAuth2 and the API |
| `MR_OAUTH_CONSUMER_KEY` / `MR_OAUTH_CONSUMER_SECRET` | OAuth2 app from the OSM website, scopes `read_prefs write_prefs write_api` |
| `MR_OVERPASS_URL` | Overpass interpreter URL |
| `APPLICATION_SECRET` / `MAPROULETTE_SECRET_KEY` | `openssl rand -base64 32` |
| `MR_SUPER_ACCOUNTS` | OSM user IDs with admin rights, comma separated |
| `MR_FRONTEND_URL` / `MR_PUBLIC_ORIGIN` | Public URL of MapRoulette |
| `JAVA_OPTS` | JVM options, e.g. `-Xmx2g` |

The app listens on port 9000. `GET /ping` is a cheap health check. The OAuth2 redirect URI to register in the OSM website is `<public url>/auth/callback`.
