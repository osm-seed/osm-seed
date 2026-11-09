# MapRoulette web

Docker image for the [MapRoulette frontend](https://github.com/maproulette/maproulette-frontend) with nginx. It serves the app and proxies `/api`, `/auth`, `/ws` and `/docs` to the backend (`maproulette-api`).

The frontend reads its URLs at build time, so this image builds it with placeholders and replaces them when the container starts:

| Env var | Description |
|---|---|
| `MR_URL` | Public URL of MapRoulette (required) |
| `MR_OSM_SERVER` | OSM website URL (required) |
| `MR_OSM_API_SERVER` | OSM API URL, default `MR_OSM_SERVER` |
| `MR_WS_URL` | WebSocket URL, default `ws(s)://<MR_URL host>/ws` |
| `MR_API_URL` | Backend URL for nginx, default `http://localhost:9000` |

Build a different version with `--build-arg VERSION=<tag>`. Keep it compatible with the `maproulette-api` version.
