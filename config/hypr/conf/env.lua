-- Environment variables
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- Chromium/Electron picks its password-store backend by sniffing
-- XDG_CURRENT_DESKTOP. It knows GNOME/KDE/Unity/XFCE but not Hyprland, so a
-- bare "Hyprland" resolves to an unknown desktop and silently falls back to the
-- plaintext "basic_text" backend -- it never tries the Secret Service at all.
-- Electron apps then report safeStorage as unavailable and refuse to persist
-- logins ("sign-in won't be saved on this device"), even with gnome-keyring
-- installed and unlocked. Appending GNOME makes Chromium select
-- gnome-libsecret and use the running keyring.
--
-- Safe for portals: xdg-desktop-portal walks this list in order and uses the
-- first <desktop>-portals.conf it finds, which is still hyprland-portals.conf
-- (default=hyprland;gtk). Screenshot/ScreenCast/GlobalShortcuts stay on
-- xdg-desktop-portal-hyprland. Keep Hyprland first for that reason.
hl.env("XDG_CURRENT_DESKTOP", "Hyprland:GNOME")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
