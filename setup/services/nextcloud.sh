#!/bin/bash
# Install and start the Nextcloud sync client.
#
# This is deliberately NOT wired into the bootstrap scripts. A sync client is
# useless until it has been pointed at a server and authenticated in a browser,
# so installing it unattended during a rebuild just leaves an unconfigured
# client sitting in the tray. On Arch it is also one of the slower AUR builds,
# which is a poor thing to put between a fresh machine and a usable desktop.
#
# Run it once, by hand, after the desktop is up:
#     setup/services/nextcloud.sh
#
# Uninstall with:
#     yay -Rns nextcloud-client      # Arch
#     brew uninstall --cask nextcloud # macOS

set -euo pipefail

case "$(uname -s)" in
    Linux)
        command -v yay &>/dev/null || { echo "yay is required; run setup/arch.sh first" >&2; exit 1; }
        echo "Installing nextcloud-client..."
        yay -S --needed --noconfirm --answerdiff None --answerclean None nextcloud-client

        # Start it as a systemd scope under the session so it is not a stray
        # child of this shell and dies with the session. The session runs under
        # uwsm (see docs/hyprland-startup.md), so uwsm-app is the right wrapper;
        # fall back to a transient scope if it is somehow unavailable.
        if [[ -n ${WAYLAND_DISPLAY:-} ]]; then
            echo "Starting Nextcloud..."
            if command -v uwsm-app &>/dev/null; then
                uwsm-app -- nextcloud --background &>/dev/null &
            else
                systemd-run --user --scope --quiet nextcloud --background &>/dev/null &
            fi
        else
            echo "No Wayland session detected; start it from your session with:"
            echo "    uwsm-app -- nextcloud --background"
        fi
        ;;
    Darwin)
        command -v brew &>/dev/null || { echo "Homebrew is required; run setup/macos.sh first" >&2; exit 1; }
        echo "Installing nextcloud..."
        brew install --cask nextcloud
        open -a Nextcloud || true
        ;;
    *)
        echo "Unsupported platform: $(uname -s)" >&2
        exit 1
        ;;
esac

cat <<'EOF'

Nextcloud installed.

Next steps, both done inside the client:
  1. Connect to your server and authenticate in the browser it opens.
  2. Enable "Launch on system startup" in its settings if you want it
     persistent - the client writes its own autostart entry
     (~/.config/autostart/Nextcloud.desktop on Linux), and uwsm activates
     xdg-desktop-autostart.target, so that entry is honoured. This script
     deliberately does not fabricate that file.

On Linux the sync status icon appears in waybar's tray module.
EOF
