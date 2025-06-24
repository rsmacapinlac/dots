# SMB Share Mounting in Ranger

This document describes the custom SMB share mounting functionality integrated into Ranger for easy access to network shares.

## Overview

The SMB mounting system provides seamless integration with Ranger file manager, allowing you to mount and access SMB shares directly from within Ranger without needing separate scripts or manual mount commands.

## Features

- **Integrated Commands**: Mount, unmount, and list shares directly in Ranger
- **Automatic Cleanup**: Shares are automatically unmounted when Ranger exits
- **Tab Completion**: Quick share name completion
- **User-Friendly**: No elevated access required for directory creation
- **Session Tracking**: Keeps track of mounted shares during the session

## Usage

### Key Mappings
- `gM` - Mount a share (prompts for share name)
- `gU` - Unmount a share (prompts for share name)
- `gS` - List all mounted shares in this session

### Available Shares
- `downloads` - Mounts ArrsDownloadShare at `~/mnt/ArrsDownloadShare`
- `media` - Mounts LocalMediaLibraryShare at `~/mnt/LocalMediaLibraryShare`

### Examples
1. **Mount a share**: Press `gM`, type `downloads`, press Enter
2. **Unmount a share**: Press `gU`, type `downloads`, press Enter
3. **List mounted shares**: Press `gS` to see all shares mounted in this session

## Automatic Cleanup

**Shares are automatically unmounted when Ranger is closed!**

The system tracks all shares mounted during the current Ranger session and automatically unmounts them when you exit Ranger. This ensures no orphaned mounts are left behind.

**Mount point directories are also removed** if they are empty after unmounting.

## How It Works

### Mount Command (`gM`)
1. Prompts for a share name
2. Checks if the share is already mounted
3. Creates the mount point if it doesn't exist
4. Mounts the share using `sudo mount -t cifs`
5. Tracks the share for automatic cleanup
6. Navigates to the mounted directory

### Unmount Command (`gU`)
1. Prompts for a share name
2. Checks if the share is mounted
3. Unmounts the share using `sudo umount`
4. Removes the share from tracking
5. Removes the mount point directory if empty

### List Command (`gS`)
1. Shows all shares mounted in the current session
2. Indicates which shares are still mounted vs. already unmounted

## Requirements

- `cifs-utils` package installed
- Sudo privileges for mounting/unmounting (but not for directory creation)
- Network connectivity to `vcr.int.macapinlac.network`

## Mount Points

Shares are mounted in `~/mnt/` (your home directory) to avoid requiring elevated access for directory creation. The mount points are:
- `~/mnt/ArrsDownloadShare` for downloads
- `~/mnt/LocalMediaLibraryShare` for media

## Configuration

The functionality is implemented through custom Ranger commands in:
- `config/ranger/commands.py` - Contains the mount/unmount commands
- `config/ranger/rc.conf` - Contains the key mappings

## Troubleshooting

### Mounting Issues
If mounting fails:
1. Check network connectivity to `vcr.int.macapinlac.network`
2. Verify sudo privileges are configured
3. Ensure `cifs-utils` package is installed
4. Check if the share is accessible from the network

### Unmounting Issues
If unmounting fails:
1. Check if any processes are using the mount
2. Verify sudo privileges
3. Try forcing unmount with `sudo umount -f`

### General Issues
- **Permission denied**: Ensure sudo is configured for mount/umount commands
- **Network unreachable**: Check network connectivity and firewall settings
- **Share not found**: Verify the share names and network paths

## Tab Completion

All commands support tab completion for share names:
- Type `gM` then `d` and press Tab to complete `downloads`
- Type `gM` then `m` and press Tab to complete `media`
- Same applies for `gU` (unmount) command

## Integration with Existing Workflow

This system replaces the previous standalone mount scripts (`mount_house.sh` and `umount_house.sh`) with a more integrated solution that:
- Works directly within Ranger
- Provides better user experience
- Includes automatic cleanup
- Supports tab completion
- Tracks session state 