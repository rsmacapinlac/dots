# Hyprland Startup Configuration

This document explains how Hyprland is launched in this system and the rationale behind the startup method choice.

## Overview

Hyprland is launched via the **greetd** display manager using the official `start-hyprland` wrapper provided by the Hyprland package. This approach ensures proper initialization and avoids compatibility issues.

Greetd is not installed by the minimal Archinstall profile. After the first
reboot into a TTY, `setup/start.sh` dispatches to the core `setup/arch.sh`
installer, which installs and enables greetd. The following reboot enters the
user's Hyprland session automatically.

## Startup Method

### Current Configuration

The system uses the **simple `start-hyprland` wrapper** approach:

- **Display Manager**: greetd
- **Configuration File**: `/etc/greetd/config.toml`
- **Startup Command**: `start-hyprland`
- **Provided By**: Hyprland package (`/usr/bin/start-hyprland`)

### Configuration Example

```toml
[terminal]
vt = 1

[default_session]
command = "start-hyprland"
user = "greeter"

[initial_session]
command = "start-hyprland"
user = "ritchie"
```

## Why start-hyprland?

The `start-hyprland` binary is the official, recommended way to launch Hyprland. It:

- **Properly initializes the Wayland environment** with required variables
- **Sets up systemd integration** for user services
- **Handles session management** correctly
- **Avoids warning messages** like "Hyprland was started without start-hyprland"
- **Is maintained by the Hyprland team** as the standard startup method

## Alternative: UWSM (Not Used)

UWSM (Universal Wayland Session Manager) is **not used for Hyprland startup** and
is **not installed** by `setup/arch.sh`. It may still be present on machines
provisioned before the core/optional split.

- **Package**: `uwsm` — not part of the core install; add it deliberately if wanted
- **Desktop File**: `/usr/share/wayland-sessions/hyprland-uwsm.desktop` (only if installed)
- **Status**: Marked as "for advanced users" with "issues and quirks"

### Why We Don't Use UWSM

1. **Simpler is better** - The official wrapper is more maintainable
2. **Advanced user tool** - UWSM is marked for advanced users with known quirks
3. **No clear benefit** - For our use case, UWSM adds complexity without advantages
4. **Official support** - `start-hyprland` is the officially supported method
5. **Avoids compatibility issues** - Prevents warnings and potential problems

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

**Solution**: Ensure `/etc/greetd/config.toml` uses `command = "start-hyprland"`

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
   - Login and manually test: `start-hyprland`
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

## Using UWSM for Advanced Use Cases

If you need UWSM for specific functionality, install it (`yay -S uwsm`). You can:

1. **Manually launch with UWSM:**
   ```bash
   uwsm start -e -D Hyprland hyprland.desktop
   ```

2. **Switch greetd to UWSM:**
   Edit `/etc/greetd/config.toml`:
   ```toml
   command = "uwsm start -e -D Hyprland hyprland.desktop"
   ```

3. **Configure UWSM environment:**
   - Global vars: `~/.config/uwsm/env`
   - Hyprland-specific: `~/.config/uwsm/env-hyprland`

**Note**: Document your specific use case if you switch to UWSM.

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
- Available but not used by default

## References

- [Hyprland Wiki: Master Tutorial](https://wiki.hypr.land/Getting-Started/Master-Tutorial/)
- [Hyprland Wiki: Systemd Startup](https://wiki.hypr.land/Useful-Utilities/Systemd-start/)
- [greetd Documentation](https://man.sr.ht/~kennylevinsen/greetd/)
- [GitHub: Hyprland "started without start-hyprland" Discussion](https://github.com/hyprwm/Hyprland/discussions/12661)
- [GitHub: uwsm vs start-hyprland Discussion](https://github.com/hyprwm/Hyprland/discussions/12805)
- [ArchWiki: greetd](https://wiki.archlinux.org/title/Greetd)
- [ArchWiki: Hyprland](https://wiki.archlinux.org/title/Hyprland)
