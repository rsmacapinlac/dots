# Dots - Personal Workstation Configuration

My comprehensive dotfiles repository for Arch Linux, macOS, and headless Debian LXC containers, featuring a complete Hyprland-based desktop environment on Arch and consistent Catppuccin theming across all applications.

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

## Quick Setup

This repository targets three environments: an Arch Linux desktop, a macOS desktop, and headless Debian LXC containers.

### Arch Linux

A rebuild has two phases separated by a reboot, and the same command is used for
both. `setup/start.sh` works out which phase it is in from where it is running:

```bash
curl -fsSL https://raw.githubusercontent.com/rsmacapinlac/dots/main/setup/start.sh | bash
```

**On the Arch live ISO** it lists the archinstall profiles in
`setup/archinstall/`, shows the target disk for confirmation, and runs
archinstall. The profile carries the disk layout, subvolumes, bootloader,
locale and timezone but deliberately no credentials — set a root password and
add a user **with sudo/wheel** in the archinstall menu, or the second phase
cannot run.

Then eject the installation media, reboot, log in, and run the same command
again.

**On the installed system** it downloads and runs `setup/arch.sh` to build the
workstation. You are asked for your password once; the rest is unattended.

Do not pipe `setup/arch.sh` into bash directly. Under `curl … | bash`,
`BASH_SOURCE[0]` is unset and `$0` is `bash`, so the guard at the end of that
script is false, `main()` never runs, and it exits successfully having done
nothing. `start.sh` downloads to a file and runs that instead.

Secrets are never handled by either phase. SSH keys, GPG keys and the password
store are restored by hand afterwards; the steps are documented at the end of
`configure_security()` in `setup/arch.sh`.

The workstation phase will:
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
- Install AI tooling (Claude Code, Codex CLI, Pi) and the Claude and ChatGPT desktop apps

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
- Install AI tooling (Claude Code, Codex CLI, Pi, agent-browser) and the Claude
  and ChatGPT desktop apps

The Claude and ChatGPT desktop apps install on both macOS and Arch, but macOS is
the only platform where AI **desktop control** and **phone-to-machine remote
control** actually work. Those require manual permission grants that no script
can perform; `setup/macos.sh` prints a checklist on completion. See
`docs/ai-desktop-control.md`.

### Debian LXC

For headless containers used for AI-agent and development work:

```bash
setup/lxc.sh
```

Command-line only by design — Claude Code, Codex CLI, and Pi, with no desktop
apps. Claude Code Remote Control is enabled here too, so an LXC session can be
driven from the Claude mobile app.

**Note**: These scripts require a regular user account with sudo privileges. Do not run as root.

## Rehearsing a Rebuild

The workstation phase runs around 30 steps, most of which only ever execute on a
fresh machine. Bugs there are invisible on a working system: the two found so far
were a missing `base-devel` and a stale `PATH`, both of which only appear when the
bootstrap itself installs the thing it later depends on. A disposable VM is the
only way to exercise that path.

`setup/archinstall/vm-test.json` is a profile targeting a 60 GiB virtio disk,
structurally identical to the real machine's profile apart from the device, disk
size and hostname.

```bash
# The ISO is ~1.5 GB — keep it outside the repo
curl -o ~/Downloads/archlinux-x86_64.iso \
  https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso

virt-install --connect qemu:///system \
  --name dots-test --memory 8192 --vcpus 4 --cpu host-passthrough \
  --disk path=/var/lib/libvirt/images/dots-test.qcow2,size=60,bus=virtio,format=qcow2 \
  --boot uefi --cdrom ~/Downloads/archlinux-x86_64.iso --os-variant archlinux \
  --graphics spice --video virtio
```

`--boot uefi` matters: `/boot` is an ESP, and a BIOS guest exercises a different
path. `--cpu host-passthrough` exposes VMX so the virtualization steps actually
run. `virt-viewer` must be installed for a usable console.

Everything below assumes the system connection, which is where the VM lives:

```bash
export LIBVIRT_DEFAULT_URI=qemu:///system
```

Run the bootstrap at the VM console rather than over SSH. A real rebuild has no
SSH, so typing it at the console is the thing being rehearsed — and two of the
bugs found so far were terminal handling that SSH would have hidden.

**Snapshot after installing and before bootstrapping.** Reverting takes seconds;
reinstalling takes an hour.

```bash
virsh shutdown dots-test
virsh change-media dots-test sda --eject --config   # or it boots the installer again
virsh snapshot-create-as dots-test clean-install "post-archinstall, pre-bootstrap"
virsh start dots-test

# after a failed attempt
virsh snapshot-revert dots-test clean-install
```

To test changes that are not yet on `main`, push a branch and point the
bootstrap at it:

```bash
DOTS_REF=my-branch bash -c 'curl -fsSL \
  https://raw.githubusercontent.com/rsmacapinlac/dots/my-branch/setup/start.sh | bash'
```

To pinpoint a failing step without re-running everything — `setup/arch.sh` skips
`main()` when sourced, which is what its `BASH_SOURCE` guard is for:

```bash
source ~/workspace/dots/setup/arch.sh   # defines functions, runs nothing
install_hyprland                        # run just the step that failed
```

Starting over completely:

```bash
virsh destroy dots-test
virsh undefine dots-test --nvram --remove-all-storage   # --nvram: the VM is UEFI
```

Hyprland and greetd are not meaningfully testable this way — a VM has no real
GPU, so failures there usually mean the VM rather than the configuration.
`install_steam` is a large download worth skipping on a first pass. Budget 45-90
minutes for a full run.

## Repository Structure

### Configuration Files (`config/`)
- **Desktop Environment**:
  - `hypr/`: Hyprland compositor, configured in Lua with modules under `hypr/conf/`
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
- Custom workflow scripts and automation tools

### Install Profiles (`setup/archinstall/`)
- `urakara.json`: the ThinkPad T470s — GRUB, btrfs, `/dev/nvme0n1`
- `vm-test.json`: 60 GiB virtio disk, for rehearsing rebuilds
- `README.md`: what the profiles encode and which values are hardware-bound

### Documentation (`docs/`)
- `isync.md`: Complete email synchronization setup guide
- `ranger-smb-mounting.md`: SMB share mounting in Ranger
- `hyprland-startup.md`: Hyprland startup and display handling
- `ai-desktop-control.md`: AI desktop control and mobile remote (macOS)

### System Files (Root Level)
- Shell configurations: `zshrc`, `aliases`, `rvmrc`
- Editor configs: `vimrc`, `vimrc.bundles`
- Email configs: `mbsyncrc`, `msmtprc`
- Dotfile management: `rcrc`
- Screen layouts: `screenlayout/`

## Key Features & Documentation

### Hyprland Desktop
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
- **[Hyprland Startup](docs/hyprland-startup.md)**: Display init and monitor handling
- **[AI Desktop Control](docs/ai-desktop-control.md)**: AI desktop control and mobile remote (macOS)
- **[Install Profiles](setup/archinstall/README.md)**: archinstall configs and which values are hardware-bound

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
