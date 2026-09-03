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
--   hypridle, hyprpaper, mako, hyprpolkitagent, quickshell
--
-- quickshell is the bar. Its unit is ours rather than packaged -- it lives in
-- config/systemd/user/quickshell.service -- but it attaches to
-- graphical-session.target the same way, so it belongs to systemd, not here.
--
-- waybar is started by neither mechanism. setup/arch.sh installs the package
-- but does not enable its unit, so it stays available as a fallback bar and
-- runs only when started by hand (`systemctl --user start waybar`). Adding an
-- exec here would undo that, and would put two bars on the screen at once.
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
