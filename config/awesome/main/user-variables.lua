local home = os.getenv("HOME")

local _M = {
  -- This is used later as the default terminal and editor to run.
  terminal = "alacritty",
   
  -- Default modkey.
  modkey = "Mod4",

  -- My customizations
  wallpaper_cmd = home .. "/workspace/wallpapers/bin/switch_wallpapers",
  launcher_cmd = "rofi -show drun -combi-modes 'window,run,ssh' -modes combi",
}

return _M
