# tiler-varnish

[Varnish](https://varnish-cache.org/) cache in front of `tiler-server-martin`, on port 6081. It uses the official `varnish:7.5` image, so there is nothing to build. `default.vcl` is the config for Docker Compose; the Helm chart keeps its own copy in `osm-seed/templates/tiler-varnish/tiler-varnish-configmap.yaml`.

| | |
|---|---|
| Image | `varnish:7.5` |
| Chart values key | `tilerVarnish` |
| Compose | `compose/tiler.yaml` service `tiler-varnish` |

- Zooms 0-5 are cached for 24 hours, zooms 6 and up for 5 days.
- Responses carry `X-Cache: HIT` or `X-Cache: MISS`.
- Add `?fresh_tiles=1` to a tile URL to render it again and replace the cached copy.
- Drop cached tiles with a `BAN` request from a private network:

```sh
curl -X BAN -H "X-Ban-Regex: ^/osm_buildings/14/" http://localhost:6081/
```
