-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
--
-- pcall(require, "luarocks.loader")

local gears         = require("gears")
local awful         = require("awful")
                      require("awful.autofocus")
local wibox         = require("wibox")
local beautiful     = require("beautiful")
local naughty       = require("naughty")
local lain          = require("lain")
--local menubar       = require("menubar")
local freedesktop   = require("freedesktop")
local hotkeys_popup = require("awful.hotkeys_popup")
                      require("awful.hotkeys_popup.keys")
local mytable       = awful.util.table or gears.table -- 4.{0,1} compatibility


-- {{ Ritchie's customizations
--
local wallpaper_cmd = os.getenv("HOME") .. "/workspace/wallpapers/bin/switch_wallpapers"
local launcher_cmd = "rofi -show drun -combi-modes 'window,run,ssh' -modes combi"

-- beautiful.useless_gap = 3

-- Test variables
--naughty.notify({ preset = naughty.config.presets.critical,
--                 title = "ugh",
--                 text = wallpaper_cmd})

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end
-- }}}

-- This function will run once every time Awesome is started
local function run_once(cmd_arr)
    for _, cmd in ipairs(cmd_arr) do
        awful.spawn.with_shell(string.format("pgrep -u $USER -fx '%s' > /dev/null || (%s)", cmd, cmd))
    end
end

run_once({ "autorandr --change" }) -- comma-separated entries
awful.spawn.with_shell(os.getenv("HOME") .. "/.config/awesome/autorun.sh")

-- {{{ Variable definitions
local themes = {
    "blackburn",       -- 1
    "copland",         -- 2
    "dremora",         -- 3
    "holo",            -- 4
    "multicolor",      -- 5
    "powerarrow",      -- 6
    "powerarrow-dark", -- 7
    "rainbow",         -- 8
    "steamburn",       -- 9
    "vertex",          -- 10
    "rsm"              -- 11
}

local chosen_theme = themes[11]
local modkey       = "Mod4"
local altkey       = "Mod1"
-- This is used later as the default terminal and editor to run.
-- terminal = "x-terminal-emulator"
local terminal     = "alacritty"
local editor       = os.getenv("EDITOR") or "editor"
local editor_cmd   = terminal .. " -e " .. editor

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
    -- awful.layout.suit.floating,
    awful.layout.suit.tile,
    -- awful.layout.suit.tile.left,
    -- awful.layout.suit.tile.bottom,
    -- awful.layout.suit.tile.top,
    -- awful.layout.suit.fair,
    -- awful.layout.suit.fair.horizontal,
    -- awful.layout.suit.spiral,
    -- awful.layout.suit.spiral.dwindle,
    -- awful.layout.suit.max,
    -- awful.layout.suit.max.fullscreen,
    -- awful.layout.suit.magnifier,
    -- awful.layout.suit.corner.nw,
    -- awful.layout.suit.corner.ne,
    -- awful.layout.suit.corner.sw,
    -- awful.layout.suit.corner.se,
}

lain.layout.termfair.nmaster           = 3
lain.layout.termfair.ncol              = 1
lain.layout.termfair.center.nmaster    = 3
lain.layout.termfair.center.ncol       = 1
lain.layout.cascade.tile.offset_x      = 2
lain.layout.cascade.tile.offset_y      = 32
lain.layout.cascade.tile.extra_padding = 5
lain.layout.cascade.tile.nmaster       = 5
lain.layout.cascade.tile.ncol          = 2

awful.util.taglist_buttons = mytable.join(
    awful.button({ }, 1, function(t) t:view_only() end),
    awful.button({ modkey }, 1, function(t)
        if client.focus then client.focus:move_to_tag(t) end
    end),
    awful.button({ }, 3, awful.tag.viewtoggle),
    awful.button({ modkey }, 3, function(t)
        if client.focus then client.focus:toggle_tag(t) end
    end),
    awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
    awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
)

awful.util.tasklist_buttons = mytable.join(
     awful.button({ }, 1, function(c)
         if c == client.focus then
             c.minimized = true
         else
             c:emit_signal("request::activate", "tasklist", { raise = true })
         end
     end),
     awful.button({ }, 3, function()
         awful.menu.client_list({ theme = { width = 250 } })
     end),
     awful.button({ }, 4, function() awful.client.focus.byidx(1) end),
     awful.button({ }, 5, function() awful.client.focus.byidx(-1) end)
)

--beautiful.init(string.format("%s/.config/awesome/themes/%s/theme.lua", os.getenv("HOME"), chosen_theme))
beautiful.init()

-- }}}

-- {{{ Menu
-- Create a launcher widget and a main menu
local myawesomemenu = {
  { "hotkeys", function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
  { "manual", terminal .. " -e man awesome" },
  { "edit config", editor_cmd .. " " .. awesome.conffile },
  { "restart", awesome.restart },
  { "quit", function() awesome.quit() end },
}

awful.util.mymainmenu = freedesktop.menu.build {
    before = {
        { "Awesome", myawesomemenu, beautiful.awesome_icon },
        -- other triads can be put here
    },
    after = {
        { "Open terminal", terminal },
        -- other triads can be put here
    }
}

-- }}}

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", function(s)
  -- Wallpaper
  awful.spawn.with_shell(wallpaper_cmd)
  --  if beautiful.wallpaper then
  --      local wallpaper = beautiful.wallpaper
  --      -- If wallpaper is a function, call it with the screen
  --      if type(wallpaper) == "function" then
  --          wallpaper = wallpaper(s)
  --      end
  --      gears.wallpaper.maximized(wallpaper, s, true)
  --  end
end)

-- No borders when rearranging only 1 non-floating or maximized client
screen.connect_signal("arrange", function (s)
    local only_one = #s.tiled_clients == 1
    for _, c in pairs(s.clients) do
        if only_one and not c.floating or c.maximized or c.fullscreen then
            c.border_width = 0
        else
            c.border_width = beautiful.border_width
        end
    end
end)

-- Create a wibox for each screen and add it
--awful.screen.connect_for_each_screen(function(s) beautiful.at_screen_connect(s) end)

--awful.screen.connect_for_each_screen(function(s)
  -- Wallpaper
--  awful.spawn.with_shell(wallpaper_cmd)
--  set_wallpaper(s)

--  beautiful.at_screen_connect(s)
  -- Each screen has its own tag table.
  -- awful.tag({ "1", "2", "3", "4", "5" }, s, awful.layout.layouts[1])
  -- local names = { "Main", "Browsing", "IM", "4", "5", "6", "7", "8", "9" }
  -- local l = awful.layout.suit  -- Just to save some typing: use an alias.
  -- local layouts = { l.tile, l.tile, l.tile, l.tile, l.tile,
  --     l.tile, l.tile, l.tile, l.tile}
  -- awful.tag(names, s, layouts)

--end)
-- }}}

-- {{{ Mouse bindings
root.buttons(mytable.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = mytable.join(
    awful.key({ "Control", "Shift"}, "w", function() awful.util.spawn(wallpaper_cmd) end,
              {description="Change wallpaper", group="Customizations"}),
    awful.key({ "Control" }, "space", function() awful.util.spawn(launcher_cmd) end,
              {description="Launch rofi", group="Customizations"}),
    -- awful.key({ modkey }, "b", function () awful.util.spawn("firefox") end,
    --          {description = "run Firefox", group = "Customizations"}),
    -- End Ritchie's stuff
    --
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),
    --awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
    --          {description = "view previous", group = "tag"}),
    -- awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
    --          {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore,
              {description = "go back", group = "tag"}),

    -- changes the focus, switch window positions
    awful.key({ modkey,           }, "h", function ()
        awful.client.focus.byidx( 1)
      end,
      {description = "focus next by index", group = "client"}
    ),
    awful.key({ modkey, "Control"   }, "h", function ()
        awful.client.swap.byidx(  1)
      end,
      {description = "swap with next client by index", group = "client"}
    ),
    awful.key({ modkey,           }, "l", function ()
        awful.client.focus.byidx(-1)
      end,
      {description = "focus previous by index", group = "client"}
    ),
    awful.key({ modkey, "Control"   }, "l", function ()
        awful.client.swap.byidx( -1)
      end,
      {description = "swap with previous client by index", group = "client"}
    ),

    -- Show main menu
    awful.key({ modkey,           }, "w", function () mymainmenu:show() end,
              {description = "show main menu", group = "awesome"}),


    -- client resize
    awful.key({ modkey, "Shift"    }, "h", function ()
        awful.tag.incmwfact( -0.01)
      end,
      {description = "resize window (left)", group = "client"}
    ),
    awful.key({ modkey, "Shift"    }, "j", function ()
        awful.client.incwfact( 0.01)
      end,
      {description = "resize window (down)", group = "client"}
    ),
    awful.key({ modkey, "Shift"    }, "k", function ()
        awful.client.incwfact(-0.01)
      end,
      {description = "resize window (up)", group = "client"}
    ),
    awful.key({ modkey, "Shift"    }, "l", function ()
        awful.tag.incmwfact( 0.01)
      end,
      {description = "resize window (right)", group = "client"}
    ),

    -- Alt-tabbing
    awful.key({ "Mod1",           }, "Tab",
      function ()
         -- awful.client.focus.history.previous()
         awful.client.focus.byidx(-1)
        if client.focus then
            client.focus:raise()
        end
      end,
      {description = "Switch focus between windows (forward)", group = "client"}
    ),

    awful.key({ "Mod1", "Shift"   }, "Tab",
      function ()
         -- awful.client.focus.history.previous()
         awful.client.focus.byidx(1)
         if client.focus then
             client.focus:raise()
         end
      end,
      {description = "Switch focus between windows (backward)", group = "client"}
    ),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    --awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)          end,
    --          {description = "increase master width factor", group = "layout"}),
    --awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)          end,
    --          {description = "decrease master width factor", group = "layout"}),
    --awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1, nil, true) end,
    --          {description = "increase the number of master clients", group = "layout"}),
    --awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1, nil, true) end,
    --          {description = "decrease the number of master clients", group = "layout"}),
    --awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1, nil, true)    end,
    --          {description = "increase the number of columns", group = "layout"}),
    --awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1, nil, true)    end,
    --          {description = "decrease the number of columns", group = "layout"}),
    --awful.key({ modkey,           }, "space", function () awful.layout.inc( 1)                end,
    --          {description = "select next", group = "layout"}),
    --awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(-1)                end,
    --          {description = "select previous", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  -- Focus restored client
                  if c then
                    c:emit_signal(
                        "request::activate", "key.unminimize", {raise = true}
                    )
                  end
              end,
              {description = "restore minimized", group = "client"}),

    -- Prompt
    --awful.key({ modkey },            "r",     function () awful.screen.focused().mypromptbox:run() end,
    --          {description = "run prompt", group = "launcher"}),

    --awful.key({ modkey }, "x",
    --          function ()
    --              awful.prompt.run {
    --                prompt       = "Run Lua code: ",
    --                textbox      = awful.screen.focused().mypromptbox.widget,
    --                exe_callback = awful.util.eval,
    --                history_path = awful.util.get_cache_dir() .. "/history_eval"
    --              }
    --          end,
    --          {description = "lua execute prompt", group = "awesome"}),
    --
    -- Menubar
    awful.key({ modkey }, "p", function() menubar.show() end,
              {description = "show the menubar", group = "launcher"})
)

clientkeys = mytable.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ "Control", "Shift"}, "q",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end ,
        {description = "minimize", group = "client"}),

    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "(un)maximize", group = "client"}),
    awful.key({ modkey, "Control" }, "m",
        function (c)
            c.maximized_vertical = not c.maximized_vertical
            c:raise()
        end ,
        {description = "(un)maximize vertically", group = "client"}),
    awful.key({ modkey, "Shift"   }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c:raise()
        end ,
        {description = "(un)maximize horizontally", group = "client"})
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        -- View tag only.
        awful.key({ "Control" }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end,
                  {description = "view tag #"..i, group = "tag"}),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
        -- Move client to tag.
        awful.key({ "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  {description = "move focused client to tag #"..i, group = "tag"}),
        -- Toggle tag on focused client.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end,
                  {description = "toggle focused client on tag #" .. i, group = "tag"})
    )
end

clientbuttons = mytable.join(
    awful.button({ }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
    end),
    awful.button({ modkey }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.resize(c)
    end)
)

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     callback = awful.client.setslave,
                     focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     screen = awful.screen.preferred,
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen,
                     size_hints_honor = false
     }
    },

    -- Floating clients.
    -- to find the class of a window: xprop WM_CLASS, then click on it
    { rule_any = {
        instance = {
          "DTA",  -- Firefox addon DownThemAll.
          "copyq",  -- Includes session name in class.
          "pinentry",
        },
        class = {
          "Arandr",
          "gnome-calculator",
          "Blueman-manager",
          "Gpick",
          "Kruler",
          "MessageWin",  -- kalarm.
          "Sxiv",
          "Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
          "Wpa_gui",
          "veromix",
          "xtightvncviewer"},

        -- Note that the name property shown in xprop might be set slightly after creation of the client
        -- and the name shown there might not match defined rules here.
        name = {
          "Event Tester",  -- xev.
        },
        role = {
          "AlarmWindow",  -- Thunderbird's calendar.
          "ConfigManager",  -- Thunderbird's about:config.
          "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
        }
      }, properties = { floating = true }},

    -- Add titlebars to normal clients and dialogs
    --{ rule_any = {type = { "normal", "dialog" }
    --  }, properties = { titlebars_enabled = true }
    --},

    -- Set Firefox to always map on the tag named "2" on screen 1.
    -- { rule = { class = "Firefox" },
    --   properties = { screen = 1, tag = "2" } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end
    --
    -- rounded corners for windows
    c.shape = function(cr,w,h)
      gears.shape.rounded_rect(cr,w,h,5)
    end
    -- c.shape = gears.shape.rounded_rect

    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", {raise = false})
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}
--

beautiful.useless_gap = 3

-- Autostart applications
awful.spawn.with_shell("autorandr --change")
awful.spawn.with_shell(wallpaper_cmd)
awful.spawn.with_shell(os.getenv("HOME") .. "/.config/awesome/autorun.sh")
--run "$HOME/.config/polybar/launch.sh"
-- awful.spawn.with_shell(os.getenv("HOME") .. "/.config/polybar/launch.sh")

