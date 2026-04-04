#!/usr/bin/env bash

# Wallpaper picker using rofi
# Integrates with the existing wallpaper system

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
WALLPAPER_DIR="$SCRIPT_DIR/.."

# Catppuccin Mocha colors for rofi
bg_color="#1e1e2e"
fg_color="#cdd6f4"
select_bg="#cba6f7"
select_fg="#11111b"
border_color="#cba6f7"

# Function to set wallpaper using the existing script
set_wallpaper() {
    local wallpaper_path="$1"

    # Check if hyprpaper is running, if not start it
    if ! pgrep -x "hyprpaper" > /dev/null; then
        hyprpaper &
        sleep 1
    fi

    # Save the wallpaper path
    echo "$wallpaper_path" > "$HOME/.wallpaper"

    # Use hyprctl to set the wallpaper on all monitors
    hyprctl hyprpaper wallpaper "eDP-1,$(cd "$WALLPAPER_DIR" && pwd)/$wallpaper_path"
    hyprctl hyprpaper wallpaper "DP-4,$(cd "$WALLPAPER_DIR" && pwd)/$wallpaper_path"

    # Optional: Generate color scheme using wal if available
    if command -v wal &> /dev/null; then
        wal -c
        wal -i "$(cd "$WALLPAPER_DIR" && pwd)/$wallpaper_path" -q
    fi

    echo "Wallpaper set to: $(basename "$wallpaper_path")"
}

# Change to wallpaper directory
cd "$WALLPAPER_DIR"

# Get current month for monthly wallpapers
month=$(date '+%Y-%m')

# Collect all wallpapers with icons and descriptions
declare -a wallpaper_options
declare -a wallpaper_paths

# Add random option
wallpaper_options+=("🎲 Random Wallpaper")
wallpaper_paths+=("RANDOM")

# Add monthly wallpapers
for wallpaper in Monthly/"$month"*; do
    if [[ -f "$wallpaper" ]]; then
        filename=$(basename "$wallpaper")
        wallpaper_options+=("📅 Monthly: ${filename%.*}")
        wallpaper_paths+=("$wallpaper")
    fi
done

# Add generic wallpapers
for wallpaper in Generic/*; do
    if [[ -f "$wallpaper" ]]; then
        filename=$(basename "$wallpaper")
        # Add different icons based on content
        if [[ "$filename" =~ anime ]]; then
            icon="🎌"
        elif [[ "$filename" =~ tree|nature|forest ]]; then
            icon="🌲"
        elif [[ "$filename" =~ sunset|sun ]]; then
            icon="🌅"
        elif [[ "$filename" =~ moon|night ]]; then
            icon="🌙"
        elif [[ "$filename" =~ retro ]]; then
            icon="🕹️"
        elif [[ "$filename" =~ art|paint ]]; then
            icon="🎨"
        else
            icon="🖼️"
        fi
        wallpaper_options+=("$icon ${filename%.*}")
        wallpaper_paths+=("$wallpaper")
    fi
done

# Create options string for rofi
options=""
for option in "${wallpaper_options[@]}"; do
    if [[ -z "$options" ]]; then
        options="$option"
    else
        options="$options\n$option"
    fi
done

# Show rofi menu
selected=$(echo -e "$options" | rofi -dmenu \
    -i \
    -p "🖼️ Choose Wallpaper" \
    -theme-str "window { background-color: $bg_color; border: 2px; border-color: $border_color; border-radius: 12px; width: 60%; location: center; }" \
    -theme-str "listview { lines: 12; columns: 1; }" \
    -theme-str "element { padding: 12px; border-radius: 8px; margin: 2px; }" \
    -theme-str "element selected { background-color: $select_bg; text-color: $select_fg; }" \
    -theme-str "element-text { color: $fg_color; }" \
    -theme-str "prompt { color: $select_bg; }" \
    -theme-str "inputbar { children: [prompt, entry]; padding: 12px; background-color: rgba(69, 71, 90, 0.5); border-radius: 8px; margin: 0 0 12px 0; }" \
    -no-custom \
    -format "s")

# Handle selection
if [[ -n "$selected" ]]; then
    # Find the index of the selected option
    for i in "${!wallpaper_options[@]}"; do
        if [[ "${wallpaper_options[$i]}" == "$selected" ]]; then
            selected_path="${wallpaper_paths[$i]}"
            break
        fi
    done
    
    if [[ "$selected_path" == "RANDOM" ]]; then
        # Use the existing random wallpaper script
        "$SCRIPT_DIR/set_wallpaper"
    else
        # Set the specific wallpaper
        set_wallpaper "$selected_path"
    fi
fi