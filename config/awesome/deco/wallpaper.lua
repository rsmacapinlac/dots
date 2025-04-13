-- Standard awesome library
local gears = require("gears")
local beautiful = require("beautiful")
local awful = require("awful")

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function set_wallpaper(s)
  awful.util.spawn(RC.vars.wallpaper_cmd)
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

