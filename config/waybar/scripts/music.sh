#!/bin/bash

# Music module for waybar
# Displays current song information from MPD

# Check if MPD is running and playing
if ! mpc status >/dev/null 2>&1; then
    echo ""
    exit 0
fi

# Get current song info
current_song=$(mpc --format "%title%" current 2>/dev/null)
current_artist=$(mpc --format "%artist%" current 2>/dev/null)

# Check if something is playing
if [ -z "$current_song" ]; then
    echo ""
    exit 0
fi

# Get play status
status=$(mpc status | grep -o "\[.*\]" | head -1)

# Format the display
if [ "$status" = "[playing]" ]; then
    # Truncate long titles/artists
    if [ ${#current_song} -gt 25 ]; then
        current_song="${current_song:0:22}..."
    fi
    if [ ${#current_artist} -gt 20 ]; then
        current_artist="${current_artist:0:17}..."
    fi
    
    echo "󰎆 $current_artist - $current_song"
elif [ "$status" = "[paused]" ]; then
    echo "󰏤 $current_artist - $current_song"
else
    echo ""
fi 