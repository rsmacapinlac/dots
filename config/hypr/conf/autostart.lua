-- Autostart
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

local home = os.getenv("HOME")

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    -- Not in PATH and not under /usr/bin; Arch ships it here. The old config
    -- pointed at /usr/bin/hyprpolkitagent, which never existed, so the agent
    -- was silently absent and GUI privilege prompts had no handler.
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd(home .. "/.config/wallpapers/bin/set_wallpaper --initial")
    -- hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,ssh")
    hl.exec_cmd("nextcloud --background")
    hl.exec_cmd(home .. "/.bin/hypr-display-init")
    hl.exec_cmd("sh -c 'sleep 4; . \"$HOME/.bin/hypr-utils\"; restart_waybar'")
    hl.exec_cmd(home .. "/.bin/hypr-monitor-watch")
end)
