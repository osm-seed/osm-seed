#!/bin/sh
# Replace build placeholders with the runtime URLs.
set -e

: "${MR_URL:?MR_URL is required, e.g. https://maproulette.osmseed.org}"
: "${MR_OSM_SERVER:?MR_OSM_SERVER is required, e.g. https://www.osmseed.org}"
MR_URL="${MR_URL%/}"
MR_OSM_API_SERVER="${MR_OSM_API_SERVER:-$MR_OSM_SERVER}"
MR_WS_URL="${MR_WS_URL:-$(echo "$MR_URL" | sed 's|^http|ws|')/ws}"
# Editors open on the same OSM server by default, not openstreetmap.org
MR_ID_EDITOR_URL="${MR_ID_EDITOR_URL:-${MR_OSM_SERVER%/}/edit}"
MR_RAPID_EDITOR_URL="${MR_RAPID_EDITOR_URL:-https://rapideditor.org/edit}"

find /var/www/maproulette -type f \( -name '*.js' -o -name '*.html' -o -name '*.json' \) \
  -exec sed -i \
    -e "s|__MR_URL__|${MR_URL}|g" \
    -e "s|__MR_WS_URL__|${MR_WS_URL}|g" \
    -e "s|__MR_OSM_SERVER__|${MR_OSM_SERVER%/}|g" \
    -e "s|__MR_OSM_API_SERVER__|${MR_OSM_API_SERVER%/}|g" \
    -e "s|__MR_ID_EDITOR_URL__|${MR_ID_EDITOR_URL%/}|g" \
    -e "s|__MR_RAPID_EDITOR_URL__|${MR_RAPID_EDITOR_URL%/}|g" \
    {} +
