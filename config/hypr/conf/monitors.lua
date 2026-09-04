-- Monitors
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

-- The built-in panel. hypr/lid-switch disables this output at runtime while
-- the machine runs clamshell, and re-enables it with `hyprctl reload`, which
-- reapplies the rule below -- so this stays the only place the panel's mode,
-- position and scale are written down.
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@60.01",
    position = "auto",
    scale    = 1.25,
})

hl.monitor({
    output   = "desc:LG Electronics LG ULTRAGEAR 405BORN09710",
    mode     = "2560x1440@99.95",
    position = "auto",
    scale    = 1,
})

-- Fallback for anything else plugged in
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- Monitor hotplug.
--
-- The lid binds in conf/binds.lua cover the lid moving, but pulling the dock
-- while the lid is already shut fires no lid event -- and leaving the panel
-- disabled there would leave the session with no display at all. These hooks
-- are what bring it back.
--
-- Omarchy solves the same problem with a socat listener on Hyprland's event
-- socket, kept alive as a systemd unit. This build exposes the events to the
-- Lua config directly, so there is no daemon to supervise, restart or leak.
local lid_switch = os.getenv("HOME") .. "/.config/hypr/lid-switch"

local function sync_lid_state()
    hl.exec_cmd(lid_switch .. " sync")
end

hl.on("monitor.added", sync_lid_state)
hl.on("monitor.removed", sync_lid_state)
