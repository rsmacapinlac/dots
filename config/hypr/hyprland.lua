-- Hyprland configuration.
-- See https://wiki.hypr.land/Configuring/Start/
--
-- Reference for the hl.* API lives at /usr/share/hypr/stubs/hl.meta.lua and the
-- shipped example config at /usr/share/hypr/hyprland.lua.
--
-- Load order matters: conf.switches must come after conf.monitors, see the note
-- in that file.

require("conf.monitors")
require("conf.env")
require("conf.autostart")
require("conf.look")
require("conf.input")
require("conf.binds")
require("conf.switches")
require("conf.rules")
