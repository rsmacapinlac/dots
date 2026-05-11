#!/usr/bin/env bash

ROFI_CONFIG_DIR="$HOME/.config/rofi"
TEMP_THEME="$ROFI_CONFIG_DIR/powermenu-theme.rasi"

cat > "$TEMP_THEME" << 'EOF'
@import "catppuccin-mocha"

* {
  background-color: transparent;
  text-color:       @text;
  border-color:     @mauve;
}

window {
    background-color: @base;
    border:           4px;
    border-color:     @mauve;
    border-radius:    12px;
    width:            25%;
    location:         center;
    anchor:           center;
    padding:          20px;
}

mainbox {
    background-color: @base;
    padding:          0;
    border:           0;
}

inputbar {
    background-color: @surface1;
    border-radius:    8px;
    padding:          12px;
    margin:           0px 0px 12px 0px;
    children:         [prompt];
}

prompt {
    text-color: @mauve;
}

listview {
    background-color: transparent;
    lines:            5;
    columns:          1;
    fixed-height:     1;
    spacing:          2px;
    scrollbar:        false;
}

element {
    background-color: @base;
    padding:          12px;
    border-radius:    8px;
    margin:           2px;
}

element selected {
    background-color: @mauve;
    text-color:       @crust;
}

element-text {
    background-color: transparent;
    text-color:       inherit;
}
EOF

options="󰐥 Lock\n󰤄 Suspend\n󰜉 Reboot\n󰤆 Shutdown\n󰗽 Logout"

selected=$(echo -e "$options" | rofi -dmenu \
    -i \
    -p "⏻ Power Menu" \
    -font "Hack Nerd Font 12" \
    -theme "$TEMP_THEME" \
    -no-custom \
    -format "s")

rm -f "$TEMP_THEME"

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
