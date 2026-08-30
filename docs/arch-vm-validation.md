# Arch VM validation

Use this after a `dots-test` workstation run to verify that the Arch setup still
installs, removes, and launches the expected desktop/TUI software.

## Install path tested

Run from the VM console as the normal user, not through `guest-exec`:

```bash
DOTS_REF=main bash -c 'curl -fsSL https://raw.githubusercontent.com/rsmacapinlac/dots/main/setup/start.sh | bash'
```

After the script completes, reboot and confirm Hyprland comes up.

## Session checks

```bash
pgrep -a Hyprland
pgrep -a waybar
HYPR_SIG=$(ls -1 /run/user/1000/hypr | head -1)
XDG_RUNTIME_DIR=/run/user/1000 HYPRLAND_INSTANCE_SIGNATURE="$HYPR_SIG" hyprctl configerrors
```

Expected:
- Hyprland is running.
- Waybar is running.
- `hyprctl configerrors` prints no errors.

## Package checks

Expected direct installs:

```bash
pacman -Q \
  cliamp btop tldr bolt ddcutil aether nautilus gvfs-smb sushi pamixer \
  libreoffice-fresh evince noto-fonts noto-fonts-emoji woff2-font-awesome \
  ttf-ia-writer ttf-jetbrains-mono-nerd qutebrowser kitty
```

Expected retired packages to be absent as direct/user-facing tools:

```bash
for p in alacritty arduino-cli arduino-language-server krdc mc mpc mpd mpv \
  ncmpcpp pavucontrol python-pyacoustid rmpc rpi-imager speech-dispatcher \
  telegram-desktop thunar thunar-volman timer-bin libreoffice-still; do
  pacman -Q "$p" >/dev/null 2>&1 && echo "PRESENT $p" || echo "absent $p"
done
```

Note: `smbclient`, `cifs-utils`, and `python-requests` may still be installed as
transitive dependencies. They should not be explicitly declared by `setup/arch.sh`.

## Removed dotfile paths

```bash
for p in \
  ~/.config/awesome \
  ~/.config/alacritty \
  ~/.config/mpd \
  ~/.config/ncmpcpp \
  ~/.config/rmpc \
  ~/.config/pomodux; do
  test -e "$p" && echo "PRESENT $p" || echo "absent $p"
done
```

Expected: all absent.

## Runtime smoke tests

Run these from a Kitty terminal inside the Hyprland session.

Terminal/TUI tools:

```bash
cliamp --version
cliamp        # verify the TUI opens, then quit
btop          # verify the TUI opens, then quit with q
tldr tar
pamixer --get-volume
boltctl
ddcutil detect    # no DDC display in a VM is acceptable; command should run
```

Document/viewer tools:

```bash
libreoffice --headless --version

tmp=$(mktemp -d)
echo 'LibreOffice conversion smoke test' > "$tmp/test.txt"
libreoffice --headless --convert-to pdf --outdir "$tmp" "$tmp/test.txt"
test -s "$tmp/test.pdf"

evince --version
evince "$tmp/test.pdf"
```

GUI apps:

```bash
qutebrowser about:blank &
nautilus --new-window "$HOME" &
aether &
evince "$tmp/test.pdf" &

pgrep -u "$USER" -x qutebrowser
pgrep -u "$USER" -x nautilus
pgrep -u "$USER" -x aether
pgrep -u "$USER" -x evince
hyprctl clients | grep -E 'class:|title:'
```

Font checks:

```bash
fc-match 'Noto Sans'
fc-match 'Noto Color Emoji'
fc-match 'iA Writer Mono S'
fc-match 'JetBrainsMono Nerd Font'
fc-match 'Font Awesome 6 Free'
```

Expected: each resolves to an installed font file.

## Last confirmed result

The post-refactor VM validation completed successfully:

- `setup/start.sh` completed from the console as user `ritchie`.
- Reboot entered Hyprland automatically.
- Waybar launched.
- `hyprctl configerrors` was clean.
- `cliamp`, `btop`, and `tldr` ran in Kitty.
- `qutebrowser`, `nautilus`, `aether`, and `evince` launched as Hyprland windows.
- LibreOffice ran headless and converted a text file to PDF.
- Retired package/config checks passed, excluding allowed transitive dependencies.
