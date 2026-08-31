-- Monitors
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@60.01",
    position = "auto",
    scale    = 1.5,
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
