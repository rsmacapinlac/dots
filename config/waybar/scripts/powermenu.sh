#!/usr/bin/env bash

# Get the options
options="Shutdown\nReboot\nLogout"

# Show the menu
selected=$(echo -e "$options" | rofi -dmenu -p "Power Menu")

# Handle the selection
case $selected in
    "Shutdown")
        systemctl poweroff
        ;;
    "Reboot")
        systemctl reboot
        ;;
    "Logout")
        hyprctl dispatch exit
        ;;
esac 