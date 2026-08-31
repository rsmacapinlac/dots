-- Autostart
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
--
-- The session is launched through uwsm (see docs/hyprland-startup.md), which
-- activates graphical-session.target. Anything shipping a systemd user unit
-- WantedBy=graphical-session.target is therefore started and supervised by
-- systemd, not from here -- setup/arch.sh enables those. Keeping a duplicate
-- exec here would start a second, unsupervised copy.
--
-- Started as units, deliberately absent below:
--   hypridle, hyprpaper, waybar, mako, hyprpolkitagent
--
-- What remains is what has no unit. Each goes through uwsm-app so it lands in
-- its own systemd scope and dies with the session instead of being reparented
-- to init. Use absolute paths: uwsm does not inherit an interactive PATH.

local home = os.getenv("HOME")

-- Launch a command as a systemd scope under the session.
local function launch(cmd)
    hl.exec_cmd("uwsm-app -- " .. cmd)
end

hl.on("hyprland.start", function()
    launch("nm-applet")
    launch("blueman-applet")
    launch(home .. "/.config/wallpapers/bin/set_wallpaper --initial")
end)
