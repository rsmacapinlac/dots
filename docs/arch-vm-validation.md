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
- Network, audio, brightness, lock, and display commands exist.

### Session-scoped services actually started

`enabled` is not `running`, and that gap once hid a broken idle timeout. The
session runs under uwsm, which activates `graphical-session.target`, so the
packaged units should be both enabled *and* started — see
[`hyprland-startup.md`](hyprland-startup.md). If the target is inactive the
session did not come up through uwsm and every unit below will be silently
absent. Check the target first, then what is actually *running*:

```bash
systemctl --user is-active graphical-session.target   # expect: active
systemctl --user list-units --state=failed            # expect: none
```

`active` is not healthy either. A unit whose process keeps dying is restarted
by systemd and still reports `ActiveState=active`, so a crash loop looks
identical to a working service. Check the restart counter:

```bash
for u in hypridle hyprpaper waybar mako hyprpolkitagent; do
  printf '%-18s %s' "$u" "$(systemctl --user show "$u" -p NRestarts --value)"; echo
done
```

Expect `0`. Anything climbing is a service that cannot start — under the old
non-systemd arrangement it would simply have been absent, which was at least
obvious.

```bash
for p in hypridle hyprpaper hyprpolkitagent mako waybar; do
  printf '%-18s ' "$p"; pgrep -x "$p" >/dev/null && echo RUNNING || echo "NOT RUNNING"
done
```

Expected: all five RUNNING. `hypridle` in particular has no fallback — if it is
not running there is no idle timeout and no automatic lock.

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
setup/applications.sh all               # complete boundary rehearsal
setup/applications.sh all               # idempotency rehearsal
```

After installing selected groups, verify only their packages and services. For
example, Syncthing is its own group:

```bash
setup/applications.sh syncthing
pacman -Q syncthing
systemctl --user is-enabled syncthing.service
```

For a complete `all` run, verify the groups with persistent state and the large
Citrix build explicitly:

```bash
pacman -Q icaclient syncthing qemu-full libvirt virt-install virt-viewer \
  virt-manager edk2-ovmf
systemctl --user is-enabled syncthing.service
systemctl --user is-active syncthing.service
systemctl is-enabled libvirtd.service virtlogd.service virtlockd.service
systemctl is-active libvirtd.service virtlogd.service virtlockd.service
virsh --connect qemu:///system net-info default
find /var/tmp -maxdepth 1 -name 'dots-icaclient.*' -print  # expect no output
```

The virtualization group must select `kvm_intel` or `kvm_amd` from the detected
CPU vendor and must not apply model-specific CPU, memory, or governor tuning.
The default libvirt network must be active, persistent, and autostarting. In a
nested test guest, log out and back in before requiring unprivileged libvirt
access so the new `libvirt` and `kvm` group memberships take effect.

## Result recording

Record the tested commit, profile, date, selected optional groups, and any VM
limitations. Do not retain an old “last confirmed” result after changing the
installer; validation claims must correspond to the current scripts.

### 2026-08-31 — commit `ec9be68` (branch `main`) plus tested working-tree fixes, profile `vm-test.json`

Full rebuild from a new 30 GiB UEFI/KVM guest, driven through the visible VM
console. Archinstall completed in 2m17s; `qemu-guest-agent` was installed and
verified before creating the `clean-install` snapshot, then the core phase ran
from that baseline.

- Core provisioning completed without errors and greetd entered Hyprland after
  reboot. `graphical-session.target` is active, no user units are failed, and
  `hyprctl configerrors` is clean.
- `hypridle`, `hyprpaper`, `waybar`, `mako`, and `hyprpolkitagent` are all
  running. All restart counters are zero except `hyprpaper` (`NRestarts=1`),
  consistent with the documented VM EGL limitation.
- The complete core package check passed, as did the four mise launchers
  (`claude`, `codex`, `gh`, and `pi`). `Ctrl+Return` opened Kitty and
  `Ctrl+Space` opened Rofi.
- `tests/vm-send-keys-test.sh` passed outside the guest. With Kitty focused in
  the visible viewer, the helper also typed and executed `printf vm-key-test`
  correctly through libvirt's console key events.
- Optional installer interface checks passed: `--help` exited 0, an unknown
  group exited 1 before sudo or an upgrade, and the fzf menu rendered and
  cancelled with Escape without selecting a group.
- The first `applications.sh all` run reached the `work` group but failed while
  packaging Citrix: its extracted payload exceeded the VM's 1.9 GiB `/tmp`
  tmpfs even though 13 GiB remained on disk. Moving the Citrix build root to
  disk-backed `/var/tmp` fixed the failure. Retrying `work syncthing` completed,
  then a full `all` rerun completed idempotently: installed packages were
  skipped, Citrix rebuilt without a quota error, Syncthing remained enabled and
  active, the temporary build directory was removed, and no user units failed.

### 2026-08-30 — commit `52399e1` (branch `standardize-on-uwsm`), profile `vm-test.json`

First rehearsal of the uwsm session. Full core phase from the `clean-install`
snapshot with `DOTS_REF=standardize-on-uwsm`, then reboot.

- `uwsm` installed; `/etc/greetd/config.toml` carries
  `uwsm start -- start-hyprland` for both sessions; all five units enabled into
  `~/.config/systemd/user/graphical-session.target.wants/`.
- After reboot the desktop came up, and **`graphical-session.target` is
  active** — the fact the whole design depends on. `hypridle`, `hyprpaper`,
  `waybar`, `mako` and `hyprpolkitagent` are all `enabled / active`, one process
  each, no duplicates, and no failed units.
- `uwsm-app` wrapping works, including for a custom script from `~/.bin`:
  `app-Hyprland-nm\x2dapplet-*.scope` and
  `app-Hyprland-hypr\x2dmonitor\x2dwatch-*.scope` are both running. The PATH
  friction seen in Omarchy's tracker did not materialise here — absolute paths
  in `conf/autostart.lua` were enough. (`hypr-monitor-watch` has since been
  removed along with the rest of the clamshell handling; the uwsm-app finding
  still stands and now applies to `set_wallpaper`.)
- `hyprctl configerrors` clean; `Ctrl+Return` opens Kitty.
- `hyprpaper` restarted twice (`NRestarts=2`) and holds no wallpaper
  (`hyprctl hyprpaper listactive` is empty), so the session shows Hyprland's
  built-in background. This is the VM's EGL limitation, not the session change
  — but note it now presents as an *active* unit rather than an absent process,
  which is harder to spot. `set_wallpaper` also still exits 0 in this case.
- Core packages all present, `uwsm 0.26.7-1` among them, and the four mise
  launchers (`claude`, `codex`, `gh`, `pi`) exist in `~/.local/bin` unused.
- Optional installer exercised for real with `applications.sh syncthing`: it
  ran one full system upgrade, installed `syncthing 2.1.3-1`, and left
  `syncthing.service` **enabled and active**. No package from any other group
  was pulled in — the core/optional boundary holds — and no user unit was
  failed afterwards.
- Timeshift, confirmed on the built system rather than inferred from the
  profiles: `timeshift` is installed (pulled in by `timeshift-autosnap`) and
  `00-timeshift-autosnap.hook` is present, but `/etc/timeshift/timeshift.json`
  does **not** exist. The hook no-ops silently on a pacman transaction rather
  than failing it, so nothing breaks — snapshots simply are not configured.

### 2026-08-30 — commit `0ec4cf7` (branch `fix-hypridle-activation`), profile `vm-test.json`

Re-run from the `clean-install` snapshot with `DOTS_REF=fix-hypridle-activation`,
to verify the hypridle fix from a fresh clone rather than a hand-edited guest.

- Core phase completed; `enable_core_services` ran without the hypridle enable.
- Fresh clone landed on `0ec4cf7`, clean tree, and rcm's symlink resolved to the
  committed `conf/autostart.lua`.
- After reboot: `hypridle`, `waybar`, `hyprpolkitagent` and `Hyprland` all
  running, while `graphical-session.target` was **inactive** and the `hypridle`
  unit was **disabled / inactive** — i.e. the process was running because
  `autostart.lua` execed it. That was the design *at the time*; the session has
  since moved to uwsm, where the target activates and these run as units
  instead. This entry is kept as the record of that run, not as current
  expected behaviour.
- `hyprctl configerrors` clean; `applications.sh` still rejects an unknown group
  with exit 1 before any sudo prompt.
- `hyprpaper` still fails, as expected — see the EGL limitation below.

### 2026-08-30 — commit `bf3da51`, profile `vm-test.json`

Full rebuild from a wiped disk, driven from the VM console.

- Live-ISO phase: profile listing, destructive confirmation (`/dev/vda`,
  `dots-test`), Archinstall completed in 2m22s with no errors.
- Core phase: completed twice — once from the first install, once from a
  reverted `clean-install` snapshot. `sudo` prompts correctly through the
  `curl | bash` pipe.
- Desktop: greetd auto-started Hyprland; Waybar up; `hyprctl configerrors`
  clean; `Ctrl+Return` opened Kitty; zsh default shell; JetBrains/BlexMono Nerd
  Font resolved; btrfs; `en_US.UTF-8`.
- `setup/applications.sh`: `--help` correct; an unknown group exits 1 *before*
  any sudo prompt or upgrade; the fzf menu renders and ESC cancels with exit 0.
- **Found:** `hypridle` was enabled but never running (no idle timeout, no
  automatic lock), reproduced on real hardware. Fixed by starting it from
  `conf/autostart.lua`; this result predates that fix.
- VM limitations: no battery module, and **no working EGL**, which the
  rehearsal cannot paper over. `hyprpaper` does not stay running, so the
  session shows Hyprland's built-in background instead of a wallpaper. Traced
  in the guest: `eglInitialize` fails with `EGL_NOT_INITIALIZED (DRI2: failed
  to create screen)`, Mesa falls back to `kms_swrast`, that fallback needs DRM
  dumb buffers on the card rather than the render node, and Hyprland already
  holds DRM master there — so `DRM_IOCTL_MODE_CREATE_DUMB` returns
  `Permission denied`. Device permissions are *not* the problem: `getfacl`
  shows `user:<user>:rw-` on the card via logind's seat ACL.

  Consequence: **any GPU-dependent behaviour is out of scope for this VM.**
  Do not read a wallpaper failure here as a config fault, and do not read a
  wallpaper success on existing hardware as proof the fresh-install path
  works. Optional groups beyond the interface checks were not installed.
