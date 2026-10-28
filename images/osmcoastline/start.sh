set -e

echo "Running coastline on $IMPORT_PBF_URL"
wget $IMPORT_PBF_URL -O planet.pbf
osmcoastline -o coastline.db planet.pbf
