vcl 4.1;

# VCL for Docker Compose. The Helm chart ships its own copy in
# osm-seed/templates/tiler-varnish/tiler-varnish-configmap.yaml.

backend martin {
    .host = "tiler-server-martin";
    .port = "80";
    .connect_timeout = 10s;
    .first_byte_timeout = 120s;
    .between_bytes_timeout = 30s;
}

acl purgers {
    "localhost";
    "127.0.0.1";
    "172.16.0.0/12";
    "10.0.0.0/8";
    "192.168.0.0/16";
}

sub vcl_recv {
    # BAN: drop cached tiles whose URL matches the X-Ban-Regex header
    if (req.method == "BAN") {
        if (!client.ip ~ purgers) {
            return (synth(403, "Forbidden"));
        }
        if (!req.http.X-Ban-Regex) {
            return (synth(400, "Missing X-Ban-Regex header"));
        }
        ban("req.url ~ " + req.http.X-Ban-Regex);
        return (synth(200, "Banned: " + req.http.X-Ban-Regex));
    }

    # fresh_tiles=1: force a MISS and replace the cached copy
    if (req.url ~ "[?&]fresh_tiles=1") {
        set req.hash_always_miss = true;
        set req.url = regsub(req.url, "[?&]fresh_tiles=1", "");
    }

    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    unset req.http.Cookie;
    unset req.http.Authorization;
}

sub vcl_backend_response {
    # Varnish is the cache, so the backend Cache-Control is ignored
    unset beresp.http.Cache-Control;
    unset beresp.http.Set-Cookie;

    # Martin echoes the request Origin and sends Vary: Origin, which stores
    # one copy per site. Tiles are public: keep a single copy for everyone.
    set beresp.http.Vary = "Accept-Encoding";

    if (bereq.url ~ "^/[^/]+/[0-5]/") {
        # Low zooms (0-5): not invalidated via BAN, refreshed by short TTL
        set beresp.ttl = 24h;
    } else {
        # Mid/high zooms (6-20): long TTL; BAN invalidates earlier
        set beresp.ttl = 5d;
    }
    set beresp.grace = 1h;
    set beresp.keep = 1d;

    set beresp.uncacheable = false;

    if (beresp.status >= 400) {
        set beresp.uncacheable = true;
        set beresp.ttl = 0s;
    }
}

sub vcl_deliver {
    set resp.http.Cache-Control = "public, max-age=60";

    # Fixed wildcard so one cached copy is valid for every site
    set resp.http.Access-Control-Allow-Origin = "*";

    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Cache = "MISS";
    }
}
