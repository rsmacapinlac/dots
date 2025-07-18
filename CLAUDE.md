# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository containing configuration files for various Linux applications and window managers. It works in conjunction with the `workstation-builder` repository to provide a complete workstation setup.

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
- Email configuration is in `mbsyncrc` and `msmtprc`

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
- Hyprland Ctrl key toggle for Citrix compatibility
- SMB share mounting integration in Ranger
- Email synchronization with multiple accounts
- Custom wallpaper management
- Theme consistency across applications

## Important Notes
- Uses `rcm` (rcup/rcdown) for dotfiles management
- Configurations assume Linux environment with systemd
- Email setup requires manual configuration per documentation
- Some configurations are hardware-specific (monitor layouts)