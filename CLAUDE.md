# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository containing configuration files for various Linux applications and window managers.

## Common Commands

### Dotfiles Management
- `rcup` - Apply/update all dotfiles configurations
- `rcup -v` - Apply with verbose output
- `rcup -t <tag>` - Apply specific tagged configurations

### Hyprland Window Manager
- `bin/toggle-ctrlmod-bindings` - Toggle Ctrl key bindings (useful for Citrix sessions)
- `hyprctl reload` - Reload Hyprland configuration
- Key configuration files:
  - `config/hypr/hyprland.conf` - Main Hyprland configuration
  - `config/hypr/keybinds_enabled.conf` - Normal keybindings
  - `config/hypr/keybinds_disabled.conf` - Disabled Ctrl bindings for Citrix

### Email Setup
- `mbsync -a` - Sync all email accounts (requires setup per docs/isync.md)
- `bin/sync-mail` - Custom email sync script with error handling
- `bin/neomutt-accounts` - Account management utility
- Email configuration is in `mbsyncrc` and `msmtprc`

### Music & Media
- `bin/rmpc-popup` - Music player popup interface
- `bin/songinfo` - Display current song information
- Music ecosystem: MPD daemon with ncmpcpp/rmpc clients

## Architecture and Structure

### Configuration Organization
- `config/` - Application-specific configuration files, organized by application name
- `bin/` - Custom scripts and utilities
- `docs/` - Documentation for specific configurations
- Root level files (`.zshrc`, `.vimrc`, etc.) - Shell and editor configurations

### Key Applications Configured
- **Hyprland**: Wayland compositor with modular configuration
- **Awesome WM**: Alternative X11 window manager with Lua-based modular config
- **Neovim**: Modular Lua configuration with plugin management
- **Alacritty**: Terminal emulator with TOML configuration
- **Neomutt**: Email client with multi-account support
- **Waybar/Polybar**: Status bars for different window managers
- **MPD/ncmpcpp/rmpc**: Music player daemon and clients
- **Ranger**: File manager with SMB mounting capabilities

### Configuration Patterns
- Modular configurations split into logical files
- Catppuccin theme used consistently across applications
- Shell aliases and functions centralized in `aliases`
- Window manager configurations include keybinding management
- Multiple monitor setups supported via autorandr

### Special Features
- Hyprland Ctrl key toggle for Citrix compatibility (`bin/toggle-ctrlmod-bindings`)
- SMB share mounting integration in Ranger (see docs/ranger-smb-mounting.md)
- Email synchronization with multiple accounts (boogienet, gmail, macapinlac)
- Custom wallpaper management with monthly/generic collections
- Theme consistency across applications using Catppuccin
- Tmux session templates via tmuxinator
- Development workflow integration (aliases for Go, Ruby, Git)

## Important Notes
- Uses `rcm` (rcup/rcdown) for dotfiles management via `rcrc` configuration
- Configurations assume Linux environment with systemd
- Email setup requires manual configuration per docs/isync.md
- Some configurations are hardware-specific (monitor layouts, autorandr profiles)
- Custom scripts in `bin/` directory provide workflow automation
- Shell aliases defined in root-level `aliases` file (loaded by zshrc)

## Development Workflow
- `bin/tat` - Tmux session management script
- `aliases` file contains development shortcuts (gob, gor, got for Go; be for Ruby)
- Tmuxinator templates in `config/tmuxinator/` for project sessions
- Git configuration with custom aliases and settings
