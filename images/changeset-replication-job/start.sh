#!/usr/bin/env bash
set -e

workingDirectory="/mnt/changesets"
mkdir -p "$workingDirectory"
CHANGESETS_REPLICATION_FOLDER="replication/changesets"

# Creating config file
# s3_dir is not set on purpose: the script would upload with the aws path and profile of the OSM servers.
# lock_file stays out of $workingDirectory, so it is never uploaded.
echo "state_file: $workingDirectory/state.yaml
db: host=$POSTGRES_HOST dbname=$POSTGRES_DB user=$POSTGRES_USER password=$POSTGRES_PASSWORD
data_dir: $workingDirectory
lock_file: /tmp/changesets.lock" >/config.yaml

# Verify the existence of the state.yaml file across all cloud providers. If it's not found, create a new one.
if [ ! -f "$workingDirectory/state.yaml" ]; then
    echo "File $workingDirectory/state.yaml does not exist in local storage"

    if [ "$CLOUDPROVIDER" == "aws" ]; then
        if aws s3 ls "$AWS_S3_BUCKET/$CHANGESETS_REPLICATION_FOLDER/state.yaml" >/dev/null 2>&1; then
            echo "File exists, downloading from AWS - $AWS_S3_BUCKET"
            aws s3 cp "$AWS_S3_BUCKET/$CHANGESETS_REPLICATION_FOLDER/state.yaml" "$workingDirectory/state.yaml"
        fi
    elif [ "$CLOUDPROVIDER" == "gcp" ]; then
        if gsutil -q stat "$GCP_STORAGE_BUCKET/$CHANGESETS_REPLICATION_FOLDER/state.yaml"; then
            echo "File exists, downloading from GCP - $GCP_STORAGE_BUCKET"
            gsutil cp "$GCP_STORAGE_BUCKET/$CHANGESETS_REPLICATION_FOLDER/state.yaml" "$workingDirectory/state.yaml"
        fi
    elif [ "$CLOUDPROVIDER" == "azure" ]; then
        state_file_exists=$(az storage blob exists --container-name "$AZURE_CONTAINER_NAME" --name "$CHANGESETS_REPLICATION_FOLDER/state.yaml" --query "exists" --output tsv)
        if [ "$state_file_exists" == "true" ]; then
            echo "File exists, downloading from Azure - $AZURE_CONTAINER_NAME"
            az storage blob download --container-name "$AZURE_CONTAINER_NAME" --name "$CHANGESETS_REPLICATION_FOLDER/state.yaml" --file "$workingDirectory/state.yaml"
        fi
    fi
    if [ ! -f "$workingDirectory/state.yaml" ]; then
        # Empty state: the script starts at file 000/000/001
        echo "{}" >"$workingDirectory/state.yaml"
    fi
fi

# Check a replication file in local storage or in the cloud.
# Returns 0 if it exists, 1 if it does not, 2 if the check failed.
replicationFileExists() {
    local file="$1" rc=0 exists
    [ -f "$workingDirectory/$file" ] && return 0
    case "$CLOUDPROVIDER" in
    "aws")
        # aws s3 ls exits with 1 when nothing matches, and with other codes on errors
        aws s3 ls "$AWS_S3_BUCKET/$CHANGESETS_REPLICATION_FOLDER/$file" >/dev/null || rc=$?
        [ "$rc" -le 1 ] && return "$rc"
        return 2
        ;;
    "gcp")
        gsutil -q stat "$GCP_STORAGE_BUCKET/$CHANGESETS_REPLICATION_FOLDER/$file" || rc=$?
        [ "$rc" -le 1 ] && return "$rc"
        return 2
        ;;
    "azure")
        exists=$(az storage blob exists --container-name "$AZURE_CONTAINER_NAME" --name "$CHANGESETS_REPLICATION_FOLDER/$file" --query "exists" --output tsv) || return 2
        [ "$exists" == "true" ] && return 0
        [ "$exists" == "false" ] && return 1
        return 2
        ;;
    *) return 1 ;;
    esac
}

sequenceFile() {
    printf "%03d/%03d/%03d.osm.gz" $(($1 / 1000000)) $(($1 / 1000 % 1000)) $(($1 % 1000))
}

# The script writes each file as "sequence + 1", so a state with sequence N means that file N+1 exists.
# The old script wrote file N. If file N exists and file N+1 does not, the state comes from the old script:
# move the sequence one step back, so the next file is N+1 and the numbering has no gap.
# Stop if a check fails, to never write again a file that is already published.
sequence=$(awk '/^sequence:/ {print $2}' "$workingDirectory/state.yaml")
if [ -n "$sequence" ] && [ "$sequence" -gt 0 ]; then
    currentFile=$(sequenceFile "$sequence")
    nextFile=$(sequenceFile $((sequence + 1)))
    nextExists=0
    replicationFileExists "$nextFile" || nextExists=$?
    currentExists=0
    replicationFileExists "$currentFile" || currentExists=$?
    if [ "$nextExists" -eq 2 ] || [ "$currentExists" -eq 2 ]; then
        echo "ERROR: Could not check $currentFile and $nextFile in $CLOUDPROVIDER storage"
        exit 1
    fi
    if [ "$currentExists" -eq 0 ] && [ "$nextExists" -eq 1 ]; then
        echo "File $currentFile exists and $nextFile does not, moving sequence from $sequence to $((sequence - 1))"
        sed -i "s/^sequence:.*/sequence: $((sequence - 1))/" "$workingDirectory/state.yaml"
    fi
fi

# Creating the replication files
generateReplication() {
    while true; do
        # Run replication script
        ruby replicate_changesets.rb /config.yaml

        # Loop through newly created files
        for local_file in $(find "$workingDirectory/" -cmin -1); do
            if [ -f "$local_file" ]; then
                # Construct the cloud path for the file
                cloud_file="$CHANGESETS_REPLICATION_FOLDER/${local_file#*$workingDirectory/}"

                # Log file transfer
                echo "$(date +%F_%H:%M:%S): Copying file $local_file to $cloud_file"

                # Handle different cloud providers
                case "$CLOUDPROVIDER" in
                "aws")
                    aws s3 cp "$local_file" "$AWS_S3_BUCKET/$cloud_file" --acl public-read
                    ;;
                "gcp")
                    gsutil cp -a public-read "$local_file" "$GCP_STORAGE_BUCKET/$cloud_file"
                    ;;
                "azure")
                    az storage blob upload \
                        --container-name "$AZURE_CONTAINER_NAME" \
                        --file "$local_file" \
                        --name "$cloud_file" \
                        --output none
                    ;;
                "local") ;;
                *)
                    echo "Unknown cloud provider: $CLOUDPROVIDER"
                    ;;
                esac
            fi
        done

        # Sleep for 60 seconds before next iteration
        sleep 60s
    done
}

# Call the function to start the replication process
generateReplication
