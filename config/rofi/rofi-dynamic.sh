#!/usr/bin/env bash

# Dynamic rofi launcher with rotating wallpaper backgrounds
WALLPAPER_DIR="$HOME/.config/wallpapers"
ROFI_CONFIG_DIR="$HOME/.config/rofi"
TEMP_THEME="$ROFI_CONFIG_DIR/dynamic-theme.rasi"

# Collect all wallpapers (Generic only)
declare -a wallpapers
wallpapers=( "$WALLPAPER_DIR"/Generic/* )
wallpaper_count=${#wallpapers[*]}

# Select random wallpaper
if [[ $wallpaper_count -gt 0 ]]; then
    index=$(shuf -i 0-$((wallpaper_count-1)) -n 1)
    selected_wallpaper="${wallpapers[$index]}"
else
    # Fallback to a solid color if no wallpapers found
    selected_wallpaper=""
fi

# Create dynamic theme with wallpaper background
cat > "$TEMP_THEME" << EOF
@import "catppuccin-mocha"

* {
  selected-active-foreground:  @crust;
  lightfg:                     @text;
  separatorcolor:              @surface0;
  urgent-foreground:           @red;
  alternate-urgent-background: @surface0;
  lightbg:                     @surface0;
  background-color:            transparent;
  border-color:                @mauve;
  normal-background:           @base;
  selected-urgent-background:  @red;
  alternate-active-background: @surface0;
  spacing:                     2;
  alternate-normal-foreground: @text;
  urgent-background:           @base;
  selected-normal-foreground:  @crust;
  active-foreground:           @mauve;
  background:                  @base;
  selected-active-background:  @mauve;
  active-background:           @base;
  selected-normal-background:  @mauve;
  alternate-normal-background: @surface0;
  foreground:                  @text;
  selected-urgent-foreground:  @crust;
  normal-foreground:           @text;
  alternate-urgent-foreground: @red;
  alternate-active-foreground: @mauve;
}

element {
    padding: 8px 12px;
    cursor:  pointer;
    spacing: 8px;
    border:  0;
    border-radius: 8px;
    margin: 2px;
    background-color: rgba(30, 30, 46, 0.8);
}

element normal.normal {
    background-color: rgba(30, 30, 46, 0.6);
    text-color:       @normal-foreground;
}
element normal.urgent {
    background-color: @urgent-background;
    text-color:       @urgent-foreground;
}
element normal.active {
    background-color: @active-background;
    text-color:       @active-foreground;
}
element selected.normal {
    background-color: rgba(203, 166, 247, 0.9);
    text-color:       @selected-normal-foreground;
}
element selected.urgent {
    background-color: @selected-urgent-background;
    text-color:       @selected-urgent-foreground;
}
element selected.active {
    background-color: @selected-active-background;
    text-color:       @selected-active-foreground;
}
element alternate.normal {
    background-color: rgba(69, 71, 90, 0.4);
    text-color:       @alternate-normal-foreground;
}
element alternate.urgent {
    background-color: @alternate-urgent-background;
    text-color:       @alternate-urgent-foreground;
}
element alternate.active {
    background-color: @alternate-active-background;
    text-color:       @alternate-active-foreground;
}
element-text {
    background-color: transparent;
    cursor:           inherit;
    highlight:        inherit;
    text-color:       inherit;
}
element-icon {
    background-color: transparent;
    size:             1.2em;
    cursor:           inherit;
    text-color:       inherit;
    margin: 0 8px 0 0;
}

window {
    padding:          20;
    border:           2;
    border-color:     @border-color;
    border-radius:    12px;
    width:            50%;
    location:         center;
    anchor:           center;
    transparency:     "real";
EOF

# Add background image if wallpaper exists
if [[ -f "$selected_wallpaper" ]]; then
    echo "    background-image: url(\"$selected_wallpaper\", both);" >> "$TEMP_THEME"
    echo "    background-color: rgba(30, 30, 46, 0.95);" >> "$TEMP_THEME"
else
    echo "    background-color: rgba(30, 30, 46, 0.95);" >> "$TEMP_THEME"
fi

cat >> "$TEMP_THEME" << EOF
}

mainbox {
    padding: 0;
    border:  0;
    background-color: transparent;
}
message {
    padding:      1px ;
    border-color: @separatorcolor;
    border:       2px dash 0px 0px ;
}
textbox {
    text-color: @foreground;
}
listview {
    padding:      2px 0px 0px ;
    scrollbar:    true;
    border-color: @separatorcolor;
    spacing:      2px ;
    fixed-height: 0;
    border:       2px dash 0px 0px ;
    background-color: transparent;
}
scrollbar {
    width:        4px ;
    padding:      0;
    handle-width: 8px ;
    border:       0;
    handle-color: @normal-foreground;
}
sidebar {
    border-color: @separatorcolor;
    border:       2px dash 0px 0px ;
}
button {
    cursor:     pointer;
    spacing:    0;
    text-color: @normal-foreground;
}
button selected {
    background-color: @selected-normal-background;
    text-color:       @selected-normal-foreground;
}
num-filtered-rows {
    expand:     false;
    text-color: Gray;
}
num-rows {
    expand:     false;
    text-color: Gray;
}
textbox-num-sep {
    expand:     false;
    str:        "/";
    text-color: Gray;
}
inputbar {
    padding:    12px;
    spacing:    8px;
    text-color: @normal-foreground;
    children:   [ "prompt","textbox-prompt-colon","entry","case-indicator" ];
    background-color: rgba(69, 71, 90, 0.95);
    border-radius: 8px;
    margin: 0 0 12px 0;
}
case-indicator {
    spacing:    0;
    text-color: @normal-foreground;
}
entry {
    text-color:        @normal-foreground;
    cursor:            text;
    spacing:           0;
    placeholder-color: @overlay0;
    placeholder:       "Type to search...";
    expand:            true;
}
prompt {
    spacing:    0;
    text-color: @normal-foreground;
}
textbox-prompt-colon {
    margin:     0px 0.3000em 0.0000em 0.0000em ;
    expand:     false;
    str:        ":";
    text-color: inherit;
}
EOF

# Launch rofi with the dynamic theme
rofi -show drun -theme "$TEMP_THEME" -show-icons -font "Hack Nerd Font 12" -display-drun "󰀻 Apps" -display-run " Run" -display-window "󰖯 Windows" "$@"

# Clean up temp theme file
rm -f "$TEMP_THEME"
