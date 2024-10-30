#!/bin/bash

# Array of shares to mount
# Format: "MOUNT_POINT SHARE_PATH OPTIONS"
SHARES=(
    "/mnt/ArrsDownloadShare //vcr.int.macapinlac.network/ArrsDownloadShare -t cifs -o rw,guest"
    "/mnt/LocalMediaLibraryShare //vcr.int.macapinlac.network/LocalMediaLibraryShare -t cifs -o rw,guest"
    # "/mnt/share2 //192.168.1.101/share2 -t cifs -o username=anotheruser,password=anotherpassword"
    # "/mnt/share3 192.168.1.102:/share3 -t nfs"
)

# Loop through each share
for SHARE in "${SHARES[@]}"; do
    # Split the string into components
    MOUNT_POINT=$(echo "$SHARE" | awk '{print $1}')
    SHARE_PATH=$(echo "$SHARE" | awk '{print $2}')
    OPTIONS=$(echo "$SHARE" | awk '{$1=""; $2=""; print $0}' | xargs) # Gets the remaining part as options

    # Check if the mount point is already mounted
    if mount | grep -q "$MOUNT_POINT"; then
        echo "Already mounted: $MOUNT_POINT"
    else
        # Create the mount point directory if it doesn't exist
        if [ ! -d "$MOUNT_POINT" ]; then
            mkdir -p "$MOUNT_POINT"
            echo "Created mount point: $MOUNT_POINT"
        fi

        # Mount the share
        echo "Mounting $SHARE_PATH to $MOUNT_POINT"
        mount $OPTIONS "$SHARE_PATH" "$MOUNT_POINT"

        # Check if the mount was successful
        if [ $? -eq 0 ]; then
            echo "Successfully mounted $MOUNT_POINT"
        else
            echo "Failed to mount $MOUNT_POINT"
        fi
    fi
done

