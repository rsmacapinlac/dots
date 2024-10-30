#!/bin/bash

# Array of mount points to unmount
# Format: "MOUNT_POINT"
MOUNTS=(
    "/mnt/ArrsDownloadShare"
    "/mnt/LocalMediaLibraryShare"
)

# Loop through each mount point
for MOUNT_POINT in "${MOUNTS[@]}"; do
    # Check if the mount point is currently mounted
    if mount | grep -q "$MOUNT_POINT"; then
        # Attempt to unmount the share
        echo "Unmounting $MOUNT_POINT"
        umount "$MOUNT_POINT"

        # Check if the unmount was successful
        if [ $? -eq 0 ]; then
            echo "Successfully unmounted $MOUNT_POINT"
            rm -Rf "$MOUNT_POINT"
        else
            echo "Failed to unmount $MOUNT_POINT"
        fi
    else
        echo "$MOUNT_POINT is not currently mounted"
    fi
done

