# Arch VM validation

Use this after a `dots-test` rebuild to verify the core/optional installer
boundary and the resulting Hyprland session.

## Core path

Run from the VM console as the normal user, not through `guest-exec`:

```bash
DOTS_REF=main bash -c 'curl -fsSL \
  https://raw.githubusercontent.com/rsmacapinlac/dots/main/setup/start.sh | bash'
```

After it completes, reboot. Greetd should enter the user's Hyprland session
automatically.

## Session checks

```bash
pgrep -a Hyprland
pgrep -a waybar
HYPR_SIG=$(find /run/user/1000/hypr -mindepth 1 -maxdepth 1 -printf '%f\n' | head -1)
XDG_RUNTIME_DIR=/run/user/1000 \
  HYPRLAND_INSTANCE_SIGNATURE="$HYPR_SIG" \
  hyprctl configerrors
```

Expected:

- Hyprland and Waybar are running.
- `hyprctl configerrors` prints no errors.
- `Ctrl+Return` opens Kitty and `Ctrl+Space` opens Rofi.
- Network, audio, brightness, lock, lid, and display commands exist.

## Core package checks

```bash
pacman -Q \
  hyprland greetd waybar rofi mako kitty \
  firefox qutebrowser \
  networkmanager bluez pipewire wireplumber bolt cups avahi \
  neovim tmux ranger nautilus sushi gvfs-smb \
  mise pass pass-otp gnome-keyring timeshift-autosnap
```

Optional packages must not be pulled in directly by core:

```bash
for package in cursor-bin chromium obs-studio neomutt claude-desktop \
  chatgpt-desktop steam virt-manager bitwarden syncthing; do
  pacman -Q "$package" >/dev/null 2>&1 \
    && echo "PRESENT $package" \
    || echo "optional/absent $package"
done
```

Some may appear as transitive dependencies; confirm unexpected packages with
`pactree -r <package>` before treating them as a boundary failure.

## Core runtime checks

Run these inside Kitty:

```bash
nvim --version
tmux -V
ranger --version
mise --version
pass --version
firefox --version
qutebrowser --version
nautilus --version
pamixer --get-volume
playerctl --version
boltctl --version
ddcutil detect       # no DDC display in a VM is acceptable
```

Confirm the lazy agent launchers exist without invoking them, since first use
downloads their current releases:

```bash
for command in claude codex gh pi; do
  test -x "$HOME/.local/bin/$command" || echo "MISSING $command"
done
```

## Optional installer checks

Verify help, rejection, interactive cancellation, and explicit selection:

```bash
setup/applications.sh --help
setup/applications.sh not-a-group       # must fail before sudo or upgrades
setup/applications.sh                   # open fzf, then cancel with Esc
setup/applications.sh media mail
```

After installing selected groups, verify only their packages and services. For
example, Syncthing is its own group:

```bash
setup/applications.sh syncthing
pacman -Q syncthing
systemctl --user is-enabled syncthing.service
```

The virtualization group must select `kvm_intel` or `kvm_amd` from the detected
CPU vendor and must not apply model-specific CPU, memory, or governor tuning.

## Result recording

Record the tested commit, profile, date, selected optional groups, and any VM
limitations. Do not retain an old “last confirmed” result after changing the
installer; validation claims must correspond to the current scripts.
