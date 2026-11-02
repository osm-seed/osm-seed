#!/usr/bin/env bash
set -e

export VOLUME_DIR=/mnt/data
export PLANET_EPOCH_DATE="${PLANET_EPOCH_DATE:-1970-01-01}"

folder_changesetsFile=planet/changesets
stateFile="$VOLUME_DIR/state.txt"
dumpFile="$VOLUME_DIR/input-latest.dump"

# Date taken from the backup filename, so the changesets dump keeps the backup's name.
BACKUP_DATE=""

# ===============================
# Download db .dump file
# ===============================
download_dump_file() {
    echo "Downloading db .dump file from cloud..."

    local temp_dump_file="$dumpFile.tmp"
    local actual_dump_url=""

    if [[ "$DUMP_CLOUD_URL" == *.txt ]]; then
        temp_txt="$VOLUME_DIR/tmp_dump_url.txt"
        aws s3 cp "$DUMP_CLOUD_URL" "$temp_txt"

        actual_dump_url=$(head -n 1 "$temp_txt")
        echo "Found dump URL in txt: $actual_dump_url"

        aws s3 cp "$actual_dump_url" "$temp_dump_file"
        rm -f "$temp_txt"
    else
        actual_dump_url="$DUMP_CLOUD_URL"
        aws s3 cp "$DUMP_CLOUD_URL" "$temp_dump_file"
    fi

    # Reuse the backup's date (YYYYMMDD-HHMM in its filename) so the changesets dump
    # shares the same name. Empty if the backup doesn't date its files.
    BACKUP_DATE=$(basename "$actual_dump_url" | grep -oE '[0-9]{8}-[0-9]{4}' | head -1)

    local is_gzip=false
    if [[ "$actual_dump_url" == *.gz ]] || [[ "$temp_dump_file" == *.gz ]]; then
        is_gzip=true
    elif command -v file >/dev/null 2>&1 && file "$temp_dump_file" 2>/dev/null | grep -q "gzip compressed"; then
        is_gzip=true
    elif head -c 2 "$temp_dump_file" 2>/dev/null | od -An -tx1 | grep -q "1f 8b"; then
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
# Upload changesets dump + state
# ===============================
upload_changesets_file() {
	echo "Uploading changesets file and updating state.txt..."

	# Link written into state.txt. PUBLIC_BASE_URL is the public domain that serves
	# the bucket (e.g. https://planet.openhistoricalmap.org). Without it, fall back
	# to the raw S3 URL built from the bucket name.
	if [ -n "$PUBLIC_BASE_URL" ]; then
		echo "${PUBLIC_BASE_URL%/}/$cloud_changesetsFile" > "$stateFile"
	else
		AWS_URL=${AWS_S3_BUCKET/s3:\/\//http:\/\/}
		echo "$AWS_URL.s3.amazonaws.com/$cloud_changesetsFile" > "$stateFile"
	fi
	aws s3 cp "$local_changesetsFile" "$AWS_S3_BUCKET/$cloud_changesetsFile" --acl public-read
	aws s3 cp "$stateFile" "$AWS_S3_BUCKET/${folder_changesetsFile}/state.txt" --acl public-read
}

# ===============================
# Generate changesets dump
# ===============================
download_dump_file

# Name the changesets dump after the backup it came from, so they stay in sync.
# Backup date is YYYYMMDD-HHMM; reformat to yymmdd_HHMM. Fall back to wall-clock.
if [ -n "$BACKUP_DATE" ]; then
    date=$(echo "$BACKUP_DATE" | sed -E 's/^[0-9]{2}([0-9]{6})-([0-9]{4})/\1_\2/')
else
    date=$(date '+%y%m%d_%H%M')
fi
local_changesetsFile=$VOLUME_DIR/changesets-${date}.osm.bz2
cloud_changesetsFile=${folder_changesetsFile}/changesets-${date}.osm.bz2

# If overwrite flag is enabled, use fixed filenames
if [ "$OVERWRITE_CHANGESETS_FILE" == "true" ]; then
	local_changesetsFile=$VOLUME_DIR/changesets-latest.osm.bz2
	cloud_changesetsFile=planet/changesets-latest.osm.bz2
fi

echo "Generating changesets dump with planet-dump-ng..."
planet-dump-ng \
	--dump-file "$dumpFile" \
	--changesets "$local_changesetsFile"

upload_changesets_file
