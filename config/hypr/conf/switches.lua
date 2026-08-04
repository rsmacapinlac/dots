-- Hardware switches
--
-- This file must be loaded AFTER conf/monitors.lua. Switch binds declared in the
-- same file as hl.monitor() calls silently stop firing.
-- See https://github.com/hyprwm/Hyprland/discussions/14858
--
-- Confirm the switch name with `hyprctl devices` if these stop working.

local home = os.getenv("HOME")

-- Lid: disable the internal display when an external monitor is connected,
-- suspend otherwise.
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd(home .. "/.bin/hypr-lid-close"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(home .. "/.bin/hypr-lid-open"),  { locked = true })
