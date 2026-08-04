-- Hardware switches
--
-- This file must be loaded AFTER conf/monitors.lua. Switch binds declared in the
-- same file as hl.monitor() calls silently stop firing.
-- See https://github.com/hyprwm/Hyprland/discussions/14858
--
-- Confirm the switch name with `hyprctl devices` if these stop working.

local home = os.getenv("HOME")

-- Lid: disable the internal display, and enable/place the primary external one
-- if any is connected. Nothing suspends. logind is set to HandleLidSwitch=ignore
-- (setup/arch.sh), so closing the lid undocked blanks every output and leaves
-- the machine awake. This is deliberate; do not read it as a missing suspend.
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd(home .. "/.bin/hypr-lid-close"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(home .. "/.bin/hypr-lid-open"),  { locked = true })
