# Dots - Ritchie's personal computer setup. 

I wouldn't go as far as calling this an operation system like Omarchy (that is way better thoughtout) that said, I like my arch setup and I don't think I'm going to be getting rid of it any time soon.

I've tried to optimize this for some hardware that I've owned.

That said, I've been looking at Omarchy and heavily relied on some of their decisions to enhance my own setup.

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
- **Kitty**: GPU-accelerated terminal emulators
- **Git**: Comprehensive configuration with aliases
- **Zsh**: Enhanced shell with oh-my-zsh and custom aliases

### Applications
- **Neomutt**: Terminal email client with multi-account support
- **Ranger**: Console file manager
- **cliamp**: Terminal music player
- **Qutebrowser**: Vim-like web browser
- **Various productivity tools**: Obsidian integration

### Theme & Aesthetics
- **Catppuccin**: Consistent color scheme across all applications
- **Nerd Fonts**: Icon fonts for enhanced UI elements
- **Custom wallpapers**: Curated collection of backgrounds

## Quick Setup

### Arch Linux

A rebuild has two phases separated by a reboot, and the same command is used for
both. `setup/start.sh` works out which phase it is in from where it is running:

```bash
# start with this
curl -fsSL https://raw.githubusercontent.com/rsmacapinlac/dots/main/setup/start.sh | bash

# reboot once its done
sudo reboot

#... then do it again
curl -fsSL https://raw.githubusercontent.com/rsmacapinlac/dots/main/setup/start.sh | bash
```

### macOS

For a complete macOS workstation setup:

```bash
setup/macos.sh
```

This script will:
- Install Homebrew and the base package set
- Configure user shell (zsh with oh-my-zsh) and npm user globals
- Set up security tools (pass, GnuPG pinentry, PassFF native host)
- Clone and apply dotfiles using rcm
- Install development tools (Neovim, tmux, Ruby, Go, Python)
- Install the terminal application stack (ranger, neomutt, mpd/ncmpcpp/rmpc, beets, cava)
- Install keyboard-friendly GUI apps (kitty, alacritty, qutebrowser, Firefox)
- Configure mise-backed, first-run installs for Claude Code, Codex CLI, Pi, and
  GitHub CLI; install agent-browser and the Claude and ChatGPT desktop apps

The Claude and ChatGPT desktop apps install on both macOS and Arch, but macOS is
the only platform where AI **desktop control** and **phone-to-machine remote
control** actually work. Those require manual permission grants that no script
can perform; `setup/macos.sh` prints a checklist on completion. See
`docs/ai-desktop-control.md`.

## Testing the Build Scripts 

The workstation phase runs around 30 steps, most of which only ever execute on a
fresh machine. Bugs there are invisible on a working system, so a disposable VM
is the only way to exercise that path. `setup/archinstall/vm-test.json` is the
rehearsal target.

See **[Testing the Build Scripts](docs/testing-build-scripts.md)** for the full procedure:
creating the VM, running both bootstrap phases at the console, snapshotting
before the workstation phase, iterating on a failure, and tearing it down.

## Repository Structure

### Configuration Files (`config/`)
- **Desktop Environment**:
  - `hypr/`: Hyprland compositor, configured in Lua with modules under `hypr/conf/`
  - `waybar/`: Status bar with custom scripts and styling
  - `rofi/`: Application launcher themes
  - `mako/`: Notification configuration

- **Terminals & Shells**:
  - `kitty/`: Primary terminal emulator
  - `tmux/`: Terminal multiplexer configuration

- **Development Tools**:
  - `nvim/`: Neovim with Lua-based modular configuration
  - `tmuxinator/`: Tmux session templates
  - `git/`: Git configuration and aliases

- **Applications**:
  - `neomutt/`: Email client with multi-account setup
  - `ranger/`: Terminal file manager
  - `qutebrowser/`: Web browser configuration
  - `obsidian/`: Note-taking integration

- **Theming**:
  - `wallpapers/`: Curated wallpaper collection
  - Various theme files with Catppuccin color schemes

### Scripts & Utilities (`bin/`)
- Custom workflow scripts and automation tools

### Archinstall Install Profiles (`setup/archinstall/`)
- `urakara.json`: the ThinkPad T470s — GRUB, btrfs, `/dev/nvme0n1`
- `vm-test.json`: 60 GiB virtio disk, for rehearsing rebuilds
- `README.md`: what the profiles encode and which values are hardware-bound

### Documentation (`docs/`)
- `isync.md`: Complete email synchronization setup guide
- `hyprland-startup.md`: Hyprland startup and display handling
- `ai-desktop-control.md`: AI desktop control and mobile remote (macOS)

### System Files (Root Level)
- Shell configurations: `zshrc`, `aliases`
- Editor configs: `vimrc`, `vimrc.bundles`
- Email configs: `mbsyncrc`, `msmtprc`
- Dotfile management: `rcrc`
- Screen layouts: `screenlayout/`

## Key Features & Documentation

### Hyprland Desktop
- **Multi-Monitor Support**: Automatic display configuration with autorandr
- **Custom Waybar**: System monitoring and power management
- **Consistent Theming**: Catppuccin colors across all desktop components

### Development Workflow
- **Neovim IDE**: LSP integration, completion, file tree, and Git integration
- **Terminal Setup**: Tmux with session management and custom key bindings
- **Shell Enhancement**: Zsh with comprehensive aliases and functions
- **Version Control**: Git configuration optimized for development workflow

### Detailed Guides
- **[Email Setup (isync)](docs/isync.md)**: Complete multi-account email configuration
- **[Hyprland Startup](docs/hyprland-startup.md)**: Display init and monitor handling
- **[Arch VM Validation](docs/arch-vm-validation.md)**: post-install package and runtime smoke checks
- **[AI Desktop Control](docs/ai-desktop-control.md)**: AI desktop control and mobile remote (macOS)
- **[Install Profiles](setup/archinstall/README.md)**: archinstall configs and which values are hardware-bound
- **[Testing the Build Scripts](docs/testing-build-scripts.md)**: exercising the bootstrap end to end in a disposable VM

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

### Manual Steps

Some things cannot be scripted and are left to do by hand after a rebuild:

- **Secrets** — SSH keys, GPG keys and the password store. The steps are
  documented at the end of `configure_security()` in `setup/arch.sh`.
- **Citrix Workspace** (`icaclient`) — Citrix puts the tarball behind a
  click-through licence rather than a fetchable URL, so `makepkg` cannot
  retrieve it. Download it from
  [Citrix](https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html),
  then:

  ```bash
  yay -G icaclient && cd icaclient
  # put the downloaded tarball in this directory
  makepkg -si
  ```

## Customization

The configuration is designed to be modular and easily customizable:

- **Colors**: All themes use Catppuccin - modify `config/hypr/conf/mocha.lua` (Hyprland),
  `config/hypr/mocha.conf` (hyprlock), and related theme files
- **Keybindings**: Hyprland bindings live in `config/hypr/conf/binds.lua`
- **Applications**: Each app configuration is self-contained in `config/`
- **Scripts**: Custom utilities in `bin/` can be modified or extended

## Requirements

- **Arch Linux** (primary target), **macOS**, or **Debian 12** (headless LXC)
- **Hyprland** compositor (Arch desktop)
- **Homebrew** (macOS)
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
