# Dots - Personal Linux Workstation Configuration

My comprehensive dotfiles repository for Arch Linux featuring a complete Hyprland-based desktop environment with consistent Catppuccin theming across all applications.

## Features

### Desktop Environment
- **Hyprland**: Modern Wayland compositor with dynamic tiling
- **Waybar**: Customizable status bar with system monitoring
- **Rofi**: Application launcher and window switcher
- **Mako**: Lightweight notification daemon
- **Swww**: Wallpaper manager for Wayland

### Development Environment
- **Neovim**: Fully configured with LSP, completion, and plugins
- **Tmux**: Terminal multiplexer with custom configuration
- **Alacritty & Kitty**: GPU-accelerated terminal emulators
- **Git**: Comprehensive configuration with aliases
- **Zsh**: Enhanced shell with oh-my-zsh and custom aliases

### Applications
- **Neomutt**: Terminal email client with multi-account support
- **Ranger**: Console file manager with SMB mounting
- **MPD/ncmpcpp/rmpc**: Music player daemon and clients
- **Qutebrowser**: Vim-like web browser
- **Various productivity tools**: Obsidian integration, Pomodoro timer

### Theme & Aesthetics
- **Catppuccin**: Consistent color scheme across all applications
- **Nerd Fonts**: Icon fonts for enhanced UI elements
- **Custom wallpapers**: Curated collection of backgrounds

## Quick Setup (Arch Linux)

For a complete Arch Linux workstation setup with all dotfiles, copy and paste this one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/rsmacapinlac/dots/main/setup/arch.sh | bash
```

This unified installation script will:
- Install all required system packages and dependencies
- Configure user shell (zsh with oh-my-zsh)
- Set up system services (Bluetooth, audio, etc.)
- Install and configure security tools (pass password manager)
- Install AUR helper (yay)
- Clone and apply dotfiles using rcm
- Install development tools (Neovim, tmux, Ruby, etc.)
- Install applications (browsers, productivity, media, Steam)
- Set up Hyprland desktop environment with all components
- Configure fonts, terminals, and file managers
- Install work tools (Citrix client)

**Note**: The script requires a regular user account with sudo privileges. Do not run as root.

## Repository Structure

### Configuration Files (`config/`)
- **Desktop Environment**:
  - `hypr/`: Hyprland compositor with modular keybinding system
  - `waybar/`: Status bar with custom scripts and styling
  - `rofi/`: Application launcher themes
  - `mako/`: Notification configuration

- **Terminals & Shells**:
  - `alacritty/`: Primary terminal emulator with Catppuccin theme
  - `kitty/`: Alternative terminal with advanced features
  - `tmux/`: Terminal multiplexer configuration

- **Development Tools**:
  - `nvim/`: Neovim with Lua-based modular configuration
  - `tmuxinator/`: Tmux session templates
  - `git/`: Git configuration and aliases

- **Applications**:
  - `neomutt/`: Email client with multi-account setup
  - `ranger/`: File manager with SMB mounting capabilities
  - `qutebrowser/`: Web browser configuration
  - `mpd/`, `ncmpcpp/`, `rmpc/`: Music ecosystem
  - `obsidian/`: Note-taking integration
  - `pomodux/`: Pomodoro timer configuration

- **Theming**:
  - `wallpapers/`: Curated wallpaper collection
  - Various theme files with Catppuccin color schemes

### Scripts & Utilities (`bin/`)
- `toggle-ctrlmod-bindings`: Toggle Ctrl key bindings for Citrix compatibility
- Custom workflow scripts and automation tools

### Documentation (`docs/`)
- `isync.md`: Complete email synchronization setup guide
- `ranger-smb-mounting.md`: SMB share mounting in Ranger

### System Files (Root Level)
- Shell configurations: `zshrc`, `aliases`, `rvmrc`
- Editor configs: `vimrc`, `vimrc.bundles`
- Email configs: `mbsyncrc`, `msmtprc`
- Dotfile management: `rcrc`
- Screen layouts: `screenlayout/`

## Key Features & Documentation

### Hyprland Desktop
- **Dynamic Keybinding System**: Toggle between normal and Citrix-compatible key mappings
- **Multi-Monitor Support**: Automatic display configuration with autorandr
- **Custom Waybar**: System monitoring with music integration and power management
- **Consistent Theming**: Catppuccin colors across all desktop components

### Development Workflow
- **Neovim IDE**: LSP integration, completion, file tree, and Git integration
- **Terminal Setup**: Tmux with session management and custom key bindings
- **Shell Enhancement**: Zsh with comprehensive aliases and functions
- **Version Control**: Git configuration optimized for development workflow

### Detailed Guides
- **[Email Setup (isync)](docs/isync.md)**: Complete multi-account email configuration
- **[Ranger SMB Mounting](docs/ranger-smb-mounting.md)**: Network share integration
- **[Hyprland Ctrl Toggle](bin/toggle-ctrlmod-bindings)**: Citrix compatibility script

## Post-Installation Usage

### Dotfile Management
```bash
# Apply all dotfiles
rcup

# Apply with verbose output
rcup -v

# Apply specific tagged configurations
rcup -t <tag>

# Remove dotfiles (use with caution)
rcdown
```

### Common Commands
```bash
# Hyprland keybinding toggle (for Citrix sessions)
bin/toggle-ctrlmod-bindings

# Email synchronization
mbsync -a

# Hyprland configuration reload
hyprctl reload

# System information
fastfetch
```

### Configuration Updates
The dotfiles are managed with `rcm`. After making changes to configurations:
1. Test changes locally
2. Commit to the repository
3. Run `rcup` to apply updates

## Customization

The configuration is designed to be modular and easily customizable:

- **Colors**: All themes use Catppuccin - modify `mocha.conf` and related theme files
- **Keybindings**: Hyprland bindings are in separate files for easy modification
- **Applications**: Each app configuration is self-contained in `config/`
- **Scripts**: Custom utilities in `bin/` can be modified or extended

## Requirements

- **Arch Linux** (primary target)
- **Hyprland** compositor
- **Zsh** shell
- **Git** for repository management
- **rcm** for dotfile management

## Contributing

This is a personal configuration repository, but you're welcome to:
- Fork and adapt for your own use
- Submit issues for bugs or improvements
- Share configuration ideas via discussions

## License

MIT License - Feel free to use and modify as needed.
