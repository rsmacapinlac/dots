#!/usr/bin/env bash
#

WALLPAPER_REPO="$HOME/workspace/wallpapers"
NEXTCLOUD_REPO="$HOME/Nextcloud/Wallpapers"

if [[ -d $WALLPAPER_REPO ]];
then
  CMD="$WALLPAPER_REPO/bin/switch_wallpapers"
elif [[ -d $NEXTCLOUD_REPO ]];
then
  CMD="feh --bg-scale --bg-fill --randomize $NEXTCLOUD_REPO"
fi

$CMD
