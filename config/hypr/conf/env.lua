-- Environment variables
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- Keep this the bare string "Hyprland". Hyprland's performUserChecks compares
-- the value against that literal and toasts a warning on any mismatch, and
-- xdg-desktop-portal matches it against hyprland-portals.conf to keep
-- Screenshot/ScreenCast/GlobalShortcuts on xdg-desktop-portal-hyprland.
--
-- This used to read "Hyprland:GNOME" to steer Chromium/Electron away from the
-- plaintext "basic_text" password store. That worked, but it only nudged
-- Chromium's autodetection rather than pinning it -- and autodetection is not
-- stable across updates. If it ever flips between the gnome-libsecret (v11)
-- and basic (v10) keys, existing cookies and saved passwords become
-- undecryptable and are silently dropped, not merely unsaved. The backend is
-- now pinned per app with --password-store=gnome-libsecret instead; see
-- config/chromium-flags.conf, local/share/applications/, and
-- docs/ai-desktop-control.md.
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
