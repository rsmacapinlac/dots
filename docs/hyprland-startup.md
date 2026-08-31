# Hyprland Startup Configuration

This document explains how Hyprland is launched in this system and the rationale behind the startup method choice.

## Overview

Hyprland is launched by the **greetd** display manager through **uwsm**
(Universal Wayland Session Manager), which in turn runs the official
`start-hyprland` wrapper:

```
uwsm start -- start-hyprland
```

uwsm does not replace `start-hyprland` — it wraps it. Both are in play.

Greetd is not installed by the minimal Archinstall profile. After the first
reboot into a TTY, `setup/start.sh` dispatches to the core `setup/arch.sh`
installer, which installs greetd and `uwsm` and enables greetd. The following
reboot enters the user's Hyprland session automatically.

## Startup Method

### Current Configuration

- **Display Manager**: greetd
- **Configuration File**: `/etc/greetd/config.toml`
- **Startup Command**: `uwsm start -- start-hyprland`
- **Provided By**: `uwsm` package, plus `start-hyprland` from the Hyprland package

### Configuration Example

```toml
[terminal]
vt = 1

[default_session]
command = "uwsm start -- start-hyprland"
user = "greeter"

[initial_session]
command = "uwsm start -- start-hyprland"
user = "<your-username>"
```

## Why uwsm

The session is a set of systemd user units, not a pile of orphaned child
processes. Concretely, uwsm activates `graphical-session-pre.target`,
`graphical-session.target` and `xdg-desktop-autostart.target`.

That last point is the whole reason this repo moved to it. Arch packages ship
user units declaring `WantedBy=graphical-session.target`:

`hypridle`, `hyprpaper`, `waybar`, `mako`, `hyprpolkitagent`

**Without a session manager that target never activates**, so those units are
enabled but never started. This is not theoretical: `hypridle` was enabled and
never ran on this configuration, which meant no idle timeout and no automatic
screen lock, and nothing surfaced an error. The old arrangement worked only
because `conf/autostart.lua` hand-execed a subset of the same programs —
`hypridle` was simply missing from that list.

Running under uwsm means:

- Those five services start and stay supervised, with systemd restart policies.
- The list is maintained by the packages, not by hand in `autostart.lua`.
- `~/.config/autostart/*.desktop` entries are honoured, because
  `xdg-desktop-autostart.target` is activated.
- Session processes die with the session rather than being reparented to init.

### How things get started

There are two mechanisms, and which one applies depends on whether the program
ships a unit.

| Program | Started by |
|---|---|
| `hypridle`, `hyprpaper`, `waybar`, `mako`, `hyprpolkitagent` | systemd user units, enabled by `setup/arch.sh` |
| `nm-applet`, `blueman-applet`, `set_wallpaper` | `conf/autostart.lua`, wrapped in `uwsm-app` |

`conf/autostart.lua` wraps each remaining command in `uwsm-app` so it lands in
its own systemd scope. **Do not exec a unit-backed service from
`autostart.lua`** — that starts a second, unsupervised copy alongside the unit.

`config/wallpapers/bin/set_wallpaper` is deliberately systemd-aware for the
same reason: it starts `hyprpaper.service` rather than forking its own copy.

### Caveat: PATH

uwsm does not inherit an interactive shell's PATH. Commands launched from
`autostart.lua` use absolute paths for anything outside the system `PATH` —
this is a known friction point with custom session scripts.

## Verifying the session

`enabled` is not `running`, and that distinction is what previously hid a
broken idle timeout. Check the target and the processes:

```bash
systemctl --user is-active graphical-session.target    # expect: active
for p in hypridle hyprpaper waybar mako hyprpolkitagent; do
  printf '%-18s ' "$p"; pgrep -x "$p" >/dev/null && echo RUNNING || echo "NOT RUNNING"
done
systemctl --user list-units --state=failed             # expect: none
```

If `graphical-session.target` is inactive, the session did not come up through
uwsm and every unit above will be silently absent.

## Making Changes

### Modifying the Startup Command

If you need to change how Hyprland starts:

1. **Edit the system configuration:**
   ```bash
   sudo vim /etc/greetd/config.toml
   ```

2. **Update the dotfiles for future installations:**
   ```bash
   vim ~/workspace/dots/setup/arch.sh
   # Edit the install_greeter() function
   ```

3. **Apply changes (logs you out!):**
   ```bash
   sudo systemctl restart greetd.service
   ```
   Or reboot for cleaner application.

### Testing Changes

After modifying the configuration:

```bash
# Check for startup warnings
journalctl -b | grep -i "hyprland was started without"

# View greetd logs
journalctl -u greetd.service -b

# Check Hyprland is running correctly
hyprctl version
```

## Troubleshooting

### Warning: "Hyprland was started without start-hyprland"

**Symptom**: This warning appears in the logs after Hyprland starts.

**Cause**: Hyprland was launched directly (via `Hyprland` command) or improperly via UWSM (using `uwsm start hyprland` instead of referencing the desktop file).

**Solution**: Ensure `/etc/greetd/config.toml` uses
`command = "uwsm start -- start-hyprland"`

### Startup Fails After Configuration Change

1. **Check greetd logs for errors:**
   ```bash
   sudo journalctl -u greetd.service -n 50
   ```

2. **Verify configuration syntax:**
   ```bash
   sudo cat /etc/greetd/config.toml
   ```

3. **Restore backup if needed:**
   ```bash
   sudo cp /etc/greetd/config.toml.backup /etc/greetd/config.toml
   sudo systemctl restart greetd.service
   ```

4. **Test from TTY:**
   - Press `Ctrl+Alt+F2` to switch to another TTY
   - Login and manually test: `uwsm start -- start-hyprland`
   - Check for error messages

### Environment Variables Not Set

If applications can't find Wayland or have display issues:

```bash
# Verify environment variables are set correctly
echo $WAYLAND_DISPLAY
echo $XDG_SESSION_TYPE
echo $XDG_CURRENT_DESKTOP

# Should output:
# wayland-1 (or similar)
# wayland
# Hyprland
```

If these are missing, the wrapper isn't being used correctly.

## Configuration Files

### System Configuration

**File**: `/etc/greetd/config.toml`
- Controls how greetd launches Hyprland
- Requires sudo to edit
- Changes take effect after restart/relogin

### Dotfiles Setup Script

**File**: `~/workspace/dots/setup/arch.sh`
- Function: `install_greeter()`
- Automatically generates greetd config during system setup
- Keeps configuration consistent across installations

### Desktop Files

**Standard**: `/usr/share/wayland-sessions/hyprland.desktop`
- Exec: `/usr/bin/start-hyprland`
- Used by display managers for session selection

**UWSM**: `/usr/share/wayland-sessions/hyprland-uwsm.desktop`
- Exec: `uwsm start -e -D Hyprland hyprland.desktop`
- Not used by greetd here: the greetd command invokes `uwsm start` directly
  against `start-hyprland` rather than going through this desktop file.
- Available but not used by default

## References

- [Hyprland Wiki: Master Tutorial](https://wiki.hypr.land/Getting-Started/Master-Tutorial/)
- [Hyprland Wiki: Systemd Startup](https://wiki.hypr.land/Useful-Utilities/Systemd-start/)
- [greetd Documentation](https://man.sr.ht/~kennylevinsen/greetd/)
- [GitHub: Hyprland "started without start-hyprland" Discussion](https://github.com/hyprwm/Hyprland/discussions/12661)
- [GitHub: uwsm vs start-hyprland Discussion](https://github.com/hyprwm/Hyprland/discussions/12805)
- [ArchWiki: greetd](https://wiki.archlinux.org/title/Greetd)
- [ArchWiki: Hyprland](https://wiki.archlinux.org/title/Hyprland)
