#!/usr/bin/env bash
cd "$(dirname "$0")"
cp ./.env.web.example ./.env.web
cp ./.env.db.example ./.env.db
cp ./.env.cloudprovider.example ./.env.cloudprovider
cp ./.env.db-utils.example ./.env.db-utils
cp ./.env.tiler-db.example ./.env.tiler-db
cp ./.env.tiler-imposm.example ./.env.tiler-imposm
cp ./.env.tiler-server.example ./.env.tiler-server
cp ./.env.nominatim.example ./.env.nominatim
cp ./.env.osmcha.example ./.env.osmcha
cp ./.env.overpass.example ./.env.overpass
cp ./.env.tasking-manager.example ./.env.tasking-manager
cp ./.env.taginfo.example ./.env.taginfo
