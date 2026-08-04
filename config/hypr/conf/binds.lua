-- Keybindings
-- See https://wiki.hypr.land/Configuring/Basics/Binds/

local home = os.getenv("HOME")

local mainMod = "SUPER"       -- "Windows" key

-- The old hyprlang config used "Control_L" here. That is a keysym, not a
-- modifier name; hyprlang only accepted it because it substring-matched
-- "CONTROL", so it always meant either Control key. The Lua parser rejects it
-- outright -- it drops the modifier and binds the bare key. Use "CTRL".
local ctrlMod = "CTRL"

local terminal  = "kitty"
local menu      = home .. "/.config/rofi/rofi-dynamic.sh"
local powermenu = home .. "/.config/waybar/scripts/powermenu.sh"
local wallpaper = home .. "/.config/wallpapers/bin/set_wallpaper"

-- Applications and session
hl.bind(ctrlMod .. " + Return",        hl.dsp.exec_cmd(terminal))
hl.bind(ctrlMod .. " + space",         hl.dsp.exec_cmd(menu))
hl.bind(ctrlMod .. " + SHIFT + W",     hl.dsp.exec_cmd(wallpaper))
hl.bind(ctrlMod .. " + ALT + Delete",  hl.dsp.exec_cmd(powermenu))
hl.bind(ctrlMod .. " + SHIFT + Q",     hl.dsp.window.close())

hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))

-- Switch workspaces with ctrlMod + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(ctrlMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
end

-- Move focus with ctrlMod + arrow keys
hl.bind(ctrlMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(ctrlMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(ctrlMod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(ctrlMod .. " + right", hl.dsp.focus({ direction = "right" }))

-- Move windows with mainMod + LMB drag
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })

-- Volume and brightness
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Media keys (requires playerctl)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Screenshots (hyprshot)
hl.bind("Print",                   hl.dsp.exec_cmd("hyprshot -m output")) -- full screen
hl.bind("SHIFT + Print",           hl.dsp.exec_cmd("hyprshot -m region")) -- select region
hl.bind(ctrlMod .. " + Print",     hl.dsp.exec_cmd("hyprshot -m window")) -- active window
