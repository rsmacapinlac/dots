# Ranger SMB Share Mounting

This document describes how to mount and navigate SMB shares directly from Ranger file manager.

## Overview

Ranger can mount SMB shares on-demand and automatically unmount them when you exit. This provides seamless access to network shares without cluttering your system with permanent mounts.

## Configuration

### External Share Configuration

Share definitions are stored in an external JSON file that is **not tracked in version control** for security:

1. **Copy the example configuration:**
   ```bash
   cp ~/.config/ranger/smb_shares.json.example ~/.config/ranger/smb_shares.json
   ```

2. **Edit the configuration file** with your own share definitions:
   ```json
   {
     "shares": {
       "downloads": {
         "mount_point": "~/mnt/ArrsDownloadShare",
         "share_path": "//your-server/your-share",
         "display_name": "Your Share Name"
       }
     }
   }
   ```

3. **Configuration fields:**
   - `mount_point`: Local directory where the share will be mounted (use `~` for home directory)
   - `share_path`: SMB path to the share (e.g., `//server/share`)
   - `display_name`: Human-readable name for the share

### Security Note

The `smb_shares.json` file is excluded from version control via `.gitignore` because it may contain sensitive network information. Always use the example file as a template.

## Usage

### Key Bindings

- `gM` - Mount a share and navigate to it
- `gU` - Unmount a share
- `gS` - List currently mounted shares

### Commands

- `:mount_share <share_name>` - Mount a specific share
- `:unmount_share <share_name>` - Unmount a specific share  
- `:list_mounted_shares` - Show all currently mounted shares

### Examples

```bash
# Mount the downloads share
:mount_share downloads

# Unmount the localmedia share
:unmount_share localmedia

# List all mounted shares
:list_mounted_shares
```

## Features

### Automatic Cleanup

When you exit Ranger, all shares mounted during the session are automatically unmounted and their mount point directories are cleaned up.

### Tab Completion

All commands support tab completion for share names based on your configuration file.

### Error Handling

- Graceful handling of mount/unmount failures
- Clear error messages for troubleshooting
- Fallback to default shares if configuration file is missing

## Requirements

- `cifs-utils` package installed
- Sudo access for mount/unmount operations
- Network access to the SMB shares

## Troubleshooting

### Mount Permission Denied
Ensure you have sudo access and the `cifs-utils` package is installed:
```bash
sudo pacman -S cifs-utils  # Arch Linux
```

### Configuration File Not Found
The system will fall back to default shares if `smb_shares.json` doesn't exist. Copy the example file to get started.

### Share Not Accessible
- Verify network connectivity to the server
- Check that the share path is correct
- Ensure the share is accessible with guest credentials (current implementation uses guest access)