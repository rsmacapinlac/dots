#!/usr/bin/env bash

# Catppuccin Mocha color scheme
bg_color="#1e1e2e"
fg_color="#cdd6f4"
select_bg="#cba6f7"
select_fg="#11111b"
border_color="#cba6f7"

# Get the options with icons
options="󰐥 Lock\n󰤄 Suspend\n󰜉 Reboot\n󰤆 Shutdown\n󰗽 Logout"

# Show the menu with custom styling
selected=$(echo -e "$options" | rofi -dmenu \
    -i \
    -p "⏻ Power Menu" \
    -theme-str "window { background-color: $bg_color; border: 2px; border-color: $border_color; border-radius: 12px; width: 25%; location: center; }" \
    -theme-str "listview { lines: 5; columns: 1; }" \
    -theme-str "element { padding: 12px; border-radius: 8px; margin: 2px; }" \
    -theme-str "element selected { background-color: $select_bg; text-color: $select_fg; }" \
    -theme-str "element-text { color: $fg_color; }" \
    -theme-str "prompt { color: $select_bg; }" \
    -theme-str "inputbar { children: [prompt]; }" \
    -no-custom \
    -format "s")

# Handle the selection
case $selected in
    "󰐥 Lock")
        hyprlock
        ;;
    "󰤄 Suspend")
        systemctl suspend
        ;;
    "󰜉 Reboot")
        systemctl reboot
        ;;
    "󰤆 Shutdown")
        systemctl poweroff
        ;;
    "󰗽 Logout")
        hyprctl dispatch exit
        ;;
esac 