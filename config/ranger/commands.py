# This is a sample commands.py.  You can add your own commands here.
#
# Please refer to commands_full.py for all the default commands and a complete
# documentation.  Do NOT add them all here, or you may end up with defunct
# commands when upgrading ranger.

# A simple command for demonstration purposes follows.
# -----------------------------------------------------------------------------

from __future__ import (absolute_import, division, print_function)

# You can import any python module as needed.
import os
import subprocess
import atexit
import json
from pathlib import Path

# You always need to import ranger.api.commands here to get the Command class:
from ranger.api.commands import Command

# Global list to track mounted shares
mounted_shares = []

# Load shares from external config file
def load_shares_config():
    """Load share definitions from external JSON config file."""
    config_path = Path(__file__).parent / "smb_shares.json"
    
    if not config_path.exists():
        # Fallback to default shares if config doesn't exist
        return {
            "downloads": {
                "mount_point": "~/mnt/ArrsDownloadShare",
                "share_path": "//vcr.int.macapinlac.network/ArrsDownloadShare",
                "display_name": "ArrsDownloadShare"
            },
            "localmedia": {
                "mount_point": "~/mnt/LocalMediaLibraryShare", 
                "share_path": "//vcr.int.macapinlac.network/LocalMediaLibraryShare",
                "display_name": "LocalMediaLibraryShare"
            },
            "savedmedia": {
                "mount_point": "~/mnt/SavedMedia",
                "share_path": "//10.1.0.96/SavedMedia", 
                "display_name": "SavedMedia"
            }
        }
    
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
            return config.get("shares", {})
    except (json.JSONDecodeError, IOError) as e:
        # Log error and return empty dict if config is invalid
        print(f"Error loading SMB shares config: {e}")
        return {}

# Load shares at module import time
SHARES = load_shares_config()

def cleanup_mounted_shares():
    """Unmount all shares that were mounted during this Ranger session"""
    for share_info in mounted_shares:
        try:
            mount_point = os.path.expanduser(share_info['mount_point'])
            display_name = share_info['display_name']
            
            if os.path.ismount(mount_point):
                subprocess.run(['sudo', 'umount', mount_point], 
                             capture_output=True, text=True, timeout=10)
                print(f"Unmounted {display_name} at {mount_point}")
                
                # Try to remove the mount point directory if it's empty
                try:
                    os.rmdir(mount_point)
                    print(f"Removed mount point directory: {mount_point}")
                except OSError as e:
                    # Directory not empty or other error - just log it
                    print(f"Could not remove mount point directory {mount_point}: {e}")
                    
        except Exception as e:
            print(f"Failed to unmount {display_name}: {e}")

# Register cleanup function to run when Python exits
atexit.register(cleanup_mounted_shares)


# Any class that is a subclass of "Command" will be integrated into ranger as a
# command.  Try typing ":my_edit<ENTER>" in ranger!
class my_edit(Command):
    # The so-called doc-string of the class will be visible in the built-in
    # help that is accessible by typing "?c" inside ranger.
    """:my_edit <filename>

    A sample command for demonstration purposes that opens a file in an editor.
    """

    # The execute method is called when you run this command in ranger.
    def execute(self):
        # self.arg(1) is the first (space-separated) argument to the function.
        # This way you can write ":my_edit somefilename<ENTER>".
        if self.arg(1):
            # self.rest(1) contains self.arg(1) and everything that follows
            target_filename = self.rest(1)
        else:
            # self.fm is a ranger.core.filemanager.FileManager object and gives
            # you access to internals of ranger.
            # self.fm.thisfile is a ranger.container.file.File object and is a
            # reference to the currently selected file.
            target_filename = self.fm.thisfile.path

        # This is a generic function to print text in ranger.
        self.fm.notify("Let's edit the file " + target_filename + "!")

        # Using bad=True in fm.notify allows you to print error messages:
        if not os.path.exists(target_filename):
            self.fm.notify("The given file does not exist!", bad=True)
            return

        # This executes a function from ranger.core.acitons, a module with a
        # variety of subroutines that can help you construct commands.
        # Check out the source, or run "pydoc ranger.core.actions" for a list.
        self.fm.edit_file(target_filename)

    # The tab method is called when you press tab, and should return a list of
    # suggestions that the user will tab through.
    # tabnum is 1 for <TAB> and -1 for <S-TAB> by default
    def tab(self, tabnum):
        # This is a generic tab-completion function that iterates through the
        # content of the current directory.
        return self._tab_directory_content()


class mount_share(Command):
    """:mount_share <share_name>

    Mount an SMB share by name and navigate to it.
    
    Available shares:
    - downloads: Mounts ArrsDownloadShare
    - localmedia: Mounts LocalMediaLibraryShare
    - savedmedia: Mounts SavedMedia
    
    Examples:
    :mount_share downloads
    :mount_share localmedia
    :mount_share savedmedia
    """

    def execute(self):
        if not self.arg(1):
            self.fm.notify("Please specify a share name (downloads, localmedia, or savedmedia)", bad=True)
            return

        share_name = self.arg(1).lower()
        
        if share_name not in SHARES:
            self.fm.notify(f"Unknown share: {share_name}. Available: {', '.join(SHARES.keys())}", bad=True)
            return
            
        share = SHARES[share_name]
        mount_point = os.path.expanduser(share['mount_point'])
        share_path = share['share_path']
        display_name = share['display_name']
        
        # Check if already mounted
        if os.path.ismount(mount_point):
            self.fm.notify(f"{display_name} is already mounted at {mount_point}")
            self.fm.cd(mount_point)
            return
            
        # Create mount point if it doesn't exist
        if not os.path.exists(mount_point):
            try:
                os.makedirs(mount_point, mode=0o755)
                self.fm.notify(f"Created mount point: {mount_point}")
            except OSError as e:
                self.fm.notify(f"Failed to create mount point: {e}", bad=True)
                return
        
        # Mount the share
        self.fm.notify(f"Mounting {display_name}...")
        try:
            result = subprocess.run([
                'sudo', 'mount', '-t', 'cifs', 
                '-o', 'rw,guest', 
                share_path, mount_point
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                self.fm.notify(f"Successfully mounted {display_name}")
                # Track this share for cleanup (store with expanded path)
                share_copy = share.copy()
                share_copy['mount_point'] = mount_point
                mounted_shares.append(share_copy)
                self.fm.cd(mount_point)
            else:
                self.fm.notify(f"Failed to mount {display_name}: {result.stderr}", bad=True)
                
        except subprocess.TimeoutExpired:
            self.fm.notify(f"Mount operation timed out for {display_name}", bad=True)
        except FileNotFoundError:
            self.fm.notify("mount command not found. Please install cifs-utils", bad=True)
        except Exception as e:
            self.fm.notify(f"Error mounting {display_name}: {e}", bad=True)

    def tab(self, tabnum):
        # Provide tab completion for available shares
        return [share for share in SHARES.keys() if share.startswith(self.rest(1))]


class unmount_share(Command):
    """:unmount_share <share_name>

    Unmount an SMB share by name.
    
    Available shares:
    - downloads: Unmounts ArrsDownloadShare
    - localmedia: Unmounts LocalMediaLibraryShare
    - savedmedia: Unmounts SavedMedia
    
    Examples:
    :unmount_share downloads
    :unmount_share localmedia
    :unmount_share savedmedia
    """

    def execute(self):
        if not self.arg(1):
            self.fm.notify("Please specify a share name (downloads, localmedia, or savedmedia)", bad=True)
            return

        share_name = self.arg(1).lower()
        
        if share_name not in SHARES:
            self.fm.notify(f"Unknown share: {share_name}. Available: {', '.join(SHARES.keys())}", bad=True)
            return
            
        share = SHARES[share_name]
        mount_point = os.path.expanduser(share['mount_point'])
        share_path = share['share_path']
        display_name = share['display_name']
        
        # Check if mounted
        if not os.path.ismount(mount_point):
            self.fm.notify(f"{display_name} is not mounted at {mount_point}")
            return
        
        # Unmount the share
        self.fm.notify(f"Unmounting {display_name}...")
        try:
            result = subprocess.run(['sudo', 'umount', mount_point], 
                                  capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                self.fm.notify(f"Successfully unmounted {display_name}")
                # Remove from tracking list
                mounted_shares[:] = [s for s in mounted_shares if s['mount_point'] != mount_point]
                
                # Try to remove the mount point directory if it's empty
                try:
                    os.rmdir(mount_point)
                    self.fm.notify(f"Removed mount point directory: {mount_point}")
                except OSError as e:
                    # Directory not empty or other error - just log it
                    self.fm.notify(f"Could not remove mount point directory {mount_point}: {e}")
            else:
                self.fm.notify(f"Failed to unmount {display_name}: {result.stderr}", bad=True)
                
        except subprocess.TimeoutExpired:
            self.fm.notify(f"Unmount operation timed out for {display_name}", bad=True)
        except Exception as e:
            self.fm.notify(f"Error unmounting {display_name}: {e}", bad=True)

    def tab(self, tabnum):
        # Provide tab completion for available shares
        return [share for share in SHARES.keys() if share.startswith(self.rest(1))]


class list_mounted_shares(Command):
    """:list_mounted_shares

    List all currently mounted SMB shares.
    """

    def execute(self):
        if not mounted_shares:
            self.fm.notify("No shares mounted in this session")
            return
            
        self.fm.notify("Mounted shares in this session:")
        for share in mounted_shares:
            mount_point = share['mount_point']
            display_name = share['display_name']
            if os.path.ismount(mount_point):
                self.fm.notify(f"  {display_name} at {mount_point}")
            else:
                self.fm.notify(f"  {display_name} at {mount_point} (not mounted)", bad=True)
