#!/usr/bin/env bash
set -e

export VOLUME_DIR=/mnt/data
export PLANET_EPOCH_DATE="${PLANET_EPOCH_DATE:-1970-01-01}"

stateFile="$VOLUME_DIR/state.txt"
dumpFile="$VOLUME_DIR/input-latest.dump"
sidecarFile="$VOLUME_DIR/input-latest.state.txt"   # seqno captured at backup time

# Filled from the sidecar (the dump's replication position + stream URL). Empty if missing.
SEQNO=""
SEQNO_TS=""
BASE_URL=""
# Date taken from the backup filename, so the planet keeps the backup's name.
BACKUP_DATE=""

# ===============================
# Download db .dump file + seqno sidecar
# ===============================
download_dump_file() {
    echo "Downloading db .dump file from cloud..."

    local temp_dump_file="$dumpFile.tmp"
    local actual_dump_url=""

    if [[ "$DUMP_CLOUD_URL" == *.txt ]]; then
        temp_txt="$VOLUME_DIR/tmp_dump_url.txt"
        aws s3 cp "$DUMP_CLOUD_URL" "$temp_txt"

        # Get the first line (S3 URL to the .dump file)
        actual_dump_url=$(head -n 1 "$temp_txt")
        echo "Found dump URL in txt: $actual_dump_url"

        aws s3 cp "$actual_dump_url" "$temp_dump_file"
        rm -f "$temp_txt"
    else
        actual_dump_url="$DUMP_CLOUD_URL"
        aws s3 cp "$DUMP_CLOUD_URL" "$temp_dump_file"
    fi

    # The backup writes a <base>.state.txt sidecar next to <base>.dump.gz. Pull it
    # so we can stamp the exact seqno into the planet. Missing sidecar is fine: the
    # planet just ships without a seqno and consumers fall back to their own logic.
    local base="${actual_dump_url%.dump.gz}"
    base="${base%.dump}"
    local sidecar_url="${base}.state.txt"

    # Reuse the backup's date (YYYYMMDD-HHMM in its filename) so the planet shares
    # the same name. Empty if the backup doesn't date its files.
    BACKUP_DATE=$(basename "$actual_dump_url" | grep -oE '[0-9]{8}-[0-9]{4}' | head -1)

    if aws s3 cp "$sidecar_url" "$sidecarFile" 2>/dev/null; then
        echo "Found seqno sidecar:"
        cat "$sidecarFile"
        SEQNO=$(awk -F= '/sequenceNumber/{print $2}' "$sidecarFile" | tr -d ' \r')
        # osmosis state.txt escapes the colons (2026-06-08T00\:00\:16Z); unescape them.
        SEQNO_TS=$(awk -F= '/^timestamp/{print $2}' "$sidecarFile" | tr -d ' \r' | sed 's/\\//g')
        BASE_URL=$(awk -F= '/replicationBaseUrl/{print $2}' "$sidecarFile" | tr -d ' \r')
        echo "Parsed seqno=$SEQNO timestamp=$SEQNO_TS baseUrl=$BASE_URL"
    else
        echo "No seqno sidecar at $sidecar_url; planet will have no sequence number"
        rm -f "$sidecarFile"
    fi

    # Check if downloaded file is gzip compressed and decompress if needed
    # Check by file extension, file type, or magic bytes
    local is_gzip=false
    if [[ "$actual_dump_url" == *.gz ]] || [[ "$temp_dump_file" == *.gz ]]; then
        is_gzip=true
    elif command -v file >/dev/null 2>&1 && file "$temp_dump_file" 2>/dev/null | grep -q "gzip compressed"; then
        is_gzip=true
    elif head -c 2 "$temp_dump_file" 2>/dev/null | od -An -tx1 | grep -q "1f 8b"; then
        # Check for gzip magic bytes (1f 8b)
        is_gzip=true
    fi

    if [ "$is_gzip" = true ]; then
        echo "Detected gzip compressed dump file, decompressing..."
        gunzip -c "$temp_dump_file" > "$dumpFile"
        rm -f "$temp_dump_file"
    else
        mv "$temp_dump_file" "$dumpFile"
    fi

    echo "Dump file ready at: $dumpFile (PostgreSQL 17 compatible)"
}

# ===============================
# Upload planet + state
# ===============================
upload_planet_file() {
	echo "Uploading planet file and updating state.txt..."

	# Link written into state.txt. PUBLIC_BASE_URL is the public domain that serves
	# the bucket (e.g. https://planet.openhistoricalmap.org). Without it, fall back
	# to the raw S3 URL built from the bucket name.
	if [ -n "$PUBLIC_BASE_URL" ]; then
		echo "${PUBLIC_BASE_URL%/}/$cloud_planetPBFFile" > "$stateFile"
	else
		AWS_URL=${AWS_S3_BUCKET/s3:\/\//http:\/\/}
		echo "$AWS_URL.s3.amazonaws.com/$cloud_planetPBFFile" > "$stateFile"
	fi
	aws s3 cp "$local_planetPBFFile" "$AWS_S3_BUCKET/$cloud_planetPBFFile" --acl public-read
	aws s3 cp "$stateFile" "$AWS_S3_BUCKET/planet/state.txt" --acl public-read

	# Publish the planet's own state.txt (seqno + timestamp) next to the PBF, the
	# same way OSM does. osmx reads the header, but this is handy for other tools.
	if [ -f "$companionStateFile" ]; then
		aws s3 cp "$companionStateFile" "$AWS_S3_BUCKET/${cloud_planetPBFFile%.osm.pbf}.state.txt" --acl public-read
	fi
}

# ===============================
# Generate planet file
# ===============================
download_dump_file

# Name the planet after the backup it came from, so the two stay in sync. The
# backup date is YYYYMMDD-HHMM; reformat it to yymmdd_HHMM. Fall back to the dump's
# data timestamp, then to wall-clock, if the backup wasn't dated.
if [ -n "$BACKUP_DATE" ]; then
    date=$(echo "$BACKUP_DATE" | sed -E 's/^[0-9]{2}([0-9]{6})-([0-9]{4})/\1_\2/')
elif [ -n "$SEQNO_TS" ]; then
    date=$(echo "$SEQNO_TS" | sed -E 's/^[0-9]{2}([0-9]{2})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}).*/\1\2\3_\4\5/')
else
    date=$(date '+%y%m%d_%H%M')
fi

local_planetPBFFile=$VOLUME_DIR/planet-${date}.osm.pbf
cloud_planetPBFFile=planet/planet-${date}.osm.pbf
companionStateFile=$VOLUME_DIR/planet-${date}.state.txt

# If overwrite flag is enabled, use fixed filenames
if [ "$OVERWRITE_PLANET_FILE" == "true" ]; then
	local_planetPBFFile=$VOLUME_DIR/planet-latest.osm.pbf
	cloud_planetPBFFile=planet/planet-latest.osm.pbf
	companionStateFile=$VOLUME_DIR/planet-latest.state.txt
fi

echo "Generating planet file with planet-dump-ng..."
if [ -n "$PLANET_DUMP_NG_METADATA_URL" ]; then
    curl "$PLANET_DUMP_NG_METADATA_URL" -o metadata.yml
    planet-dump-ng \
        --dump-file "$dumpFile" \
        --pbf "$local_planetPBFFile" \
        -M metadata.yml
else
    planet-dump-ng \
        --dump-file "$dumpFile" \
        --pbf "$local_planetPBFFile"
fi

# planet-dump-ng writes the replication timestamp but not the sequence number.
# Stamp the seqno we captured at backup time into the header so osmx can expand
# the planet and resume replication on its own. Also drop a companion state.txt.
if [ -n "$SEQNO" ]; then
    echo "Writing seqno=$SEQNO into the planet header"
    headerArgs=(--output-header=osmosis_replication_sequence_number="$SEQNO")
    [ -n "$BASE_URL" ] && headerArgs+=(--output-header=osmosis_replication_base_url="$BASE_URL")
    osmium cat "$local_planetPBFFile" -o "$local_planetPBFFile.tmp.pbf" "${headerArgs[@]}"
    mv "$local_planetPBFFile.tmp.pbf" "$local_planetPBFFile"

    {
        echo "sequenceNumber=$SEQNO"
        [ -n "$SEQNO_TS" ] && echo "timestamp=$SEQNO_TS"
        [ -n "$BASE_URL" ] && echo "replicationBaseUrl=$BASE_URL"
    } > "$companionStateFile"
else
    echo "WARNING: no seqno captured; planet header left without a sequence number"
fi

# Upload results
upload_planet_file
