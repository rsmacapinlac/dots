# Dots - Ritchie's personal computer setup. 

I wouldn't go as far as calling this an operation system like Omarchy (that is way better thoughtout) that said, I like my arch setup and I don't think I'm going to be getting rid of it any time soon.

I've tried to optimize this for some hardware that I've owned.

I've been looking at Omarchy and heavily relied on (Read: blatantly copied) some of their decisions to enhance my own setup.

## Features

### Desktop Environment
- **Hyprland**: Modern Wayland compositor with dynamic tiling
- **Waybar**: Customizable status bar with system monitoring
- **Rofi**: Application launcher and window switcher
- **Mako**: Lightweight notification daemon
- **Hyprpaper**: Wallpaper manager for Wayland

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

A rebuild has three stages and the same bootstrap command is used for the first
two. `setup/start.sh` detects whether it is running on the live ISO or the
installed system:

```bash
# start with this
curl -fsSL https://raw.githubusercontent.com/rsmacapinlac/dots/main/setup/start.sh | bash

# reboot into the installed system, log in at the TTY, then run it again
sudo reboot

curl -fsSL https://raw.githubusercontent.com/rsmacapinlac/dots/main/setup/start.sh | bash

# reboot into Hyprland, then choose any optional application groups
sudo reboot
~/workspace/dots/setup/applications.sh
```

The first invocation delegates to `setup/archinstall/install.sh`. The second
installs the core Hyprland workstation through `setup/arch.sh`. Optional
software is deliberately deferred until the machine boots into its usable
desktop; select groups interactively or name them explicitly:

```bash
setup/applications.sh media mail
setup/applications.sh all
```

### macOS

macOS lives in its own repository now:
[`dots-macos`](https://github.com/rsmacapinlac/dots-macos). It holds the
Homebrew bootstrap, the maintenance script, and macOS builds of the three
config files that needed a Darwin branch. It clones this repository for
everything else.

```bash
git clone https://github.com/rsmacapinlac/dots-macos.git ~/workspace/dots-macos
~/workspace/dots-macos/setup/macos.sh
```

This repository targets Linux: Arch for the desktop, Debian for headless LXC.

## Testing the Build Scripts 

The core phase contains many steps that only execute on a fresh machine. Bugs
there are invisible on a working system, so a disposable VM is the only way to
exercise that path. `setup/archinstall/vm-test.json` is the rehearsal target.

Run the local console-helper test before starting the longer VM rehearsal:

```bash
tests/vm-send-keys-test.sh
```

See **[Testing the Build Scripts](docs/testing-build-scripts.md)** for the full procedure:
host virtualization preflight, local syntax checks, creating the VM, driving
both bootstrap phases through the visible console, snapshotting before the core
phase, verifying Hyprland, testing all optional groups and idempotency, and
tearing the guest down.

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

### Optional Service Installers (`setup/services/`)
- `nextcloud.sh`: Nextcloud sync client
- `todoist.sh`: Todoist as a Chromium web app

Account-bound apps that are useless until you sign in, so they are kept out of
the bootstrap scripts and run once, by hand, after the desktop is up.

### Archinstall Install Profiles (`setup/archinstall/`)
- `urakara.json`: the ThinkPad T470s — GRUB, btrfs, `/dev/nvme0n1`
- `vm-test.json`: 30 GiB virtio disk, for rehearsing rebuilds
- `install.sh`: live-ISO profile selection and Archinstall execution
- `README.md`: what the profiles encode and which values are hardware-bound

### Documentation (`docs/`)
- `hyprland-startup.md`: Hyprland startup, greetd, and display handling
- `arch-vm-validation.md`: post-install package and runtime smoke checks
- `ai-desktop-control.md`: the AI desktop apps, and which of their capabilities work here
- `mise.md`: the mise-backed tool launchers and where they sit on `PATH`
- `testing-build-scripts.md`: exercising the bootstrap in a disposable VM

Mail setup is documented in the private companion repo, alongside the configs
and scripts it describes.

### System Files (Root Level)
- Shell configurations: `zshrc`, `aliases`
- Editor configs: `vimrc`, `vimrc.bundles`
- Dotfile management: `rcrc`

### Private Companion Repository

This repo is public and holds configuration that is true for any workstation,
including sensible defaults. Anything true only for one person — mail accounts
and the neomuttrc that binds them, git identity, agent settings naming private
repositories — lives in a separate private repo, listed **first**:

```sh
DOTFILES_DIRS="$HOME/workspace/dots-crispy-meme $HOME/workspace/dots"
```

`rcm` deploys the first tree that provides a given path, so private files
override the public defaults. The order is load-bearing: reversed, the public
default `neomuttrc` would shadow the real one and mail would quietly stop
working.

Clone them side by side before running `rcup`. Without the private repo the
desktop still comes up and neomutt still starts — it just has no accounts.

## Key Features & Documentation

### Hyprland Desktop
- **Multi-Monitor Support**: Declarative per-output rules in
  `config/hypr/conf/monitors.lua`. Lid handling is left to systemd-logind
  defaults (closing the lid suspends); there is no clamshell mode.
- **Custom Waybar**: System monitoring and power management
- **Consistent Theming**: Catppuccin colors across all desktop components

### Development Workflow
- **Neovim IDE**: LSP integration, completion, file tree, and Git integration
- **Terminal Setup**: Tmux with session management and custom key bindings
- **Shell Enhancement**: Zsh with comprehensive aliases and functions

### Detailed Guides
- **[Hyprland Startup](docs/hyprland-startup.md)**: Display init and monitor handling
- **[Arch VM Validation](docs/arch-vm-validation.md)**: post-install package and runtime smoke checks
- **[AI Desktop Control](docs/ai-desktop-control.md)**: the AI desktop apps, and which of their capabilities work here
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
  documented below. The core installer intentionally creates no secrets.
- **Citrix Workspace** (`icaclient`) — install it with
  `setup/applications.sh work`. The installer uses the AUR recipe when it is
  current and applies a verified local version/checksum bump when necessary.
  The AUR PKGBUILD *does* fetch the
  tarball on its own: it scrapes a signed, time-limited URL off the Citrix
  download page, so no click-through download is needed. What breaks instead is
  version drift. Citrix serves only the current release, while the PKGBUILD
  pins `pkgver` and filters the page for that exact version:

  ```bash
  _dl_urls="$(echo "$_dl_urls_" | grep -F "$pkgver.tar.gz?__gda__")"
  ```

  When the AUR package falls behind Citrix — as of 2026-08-31 it pins
  `26.04.0.105` while Citrix ships `26.04.10.1`, flagged out-of-date since
  2026-08-15 — that filter matches nothing, the source URL comes out empty and
  `makepkg` fails. The old tarball is gone from Citrix's servers, so
  downloading it by hand does not help either.

  Check the AUR first; if it has caught up, plain `yay -S icaclient` works. If
  it has not, bump it locally:

  ```bash
  yay -G icaclient && cd icaclient
  # 1. set pkgver to the version Citrix currently serves, and pkgrel=1
  # 2. replace sha256sums_x86_64 with the new tarball's checksum
  #    (makepkg will print the expected value on the first mismatch)
  makepkg -si
  ```

  A local bump means `yay` sees your build as newer than the AUR's and stops
  offering updates — recheck the AUR before a `maintenance/arch.sh` run.

  Dependencies: `libc++`, `libc++abi`, `libxml2-legacy` and `libxp` all come
  from `extra`. The PKGBUILD's optdepends are stale — it names `webkit2gtk` and
  `libsoup`, which no longer exist in the repos (they are now `webkit2gtk-4.1`
  and `libsoup3`, providing newer ABIs than Citrix links against). Only
  `selfservice` needs them, and satisfying it means pulling AUR `webkit2gtk`
  (4.0 ABI) plus AUR `libsoup` (2.4 ABI). The `wfica` session client itself
  links cleanly without either. `libsane.so.1` (`sane`) and `libfuse3.so.3`
  (`fuse3`) are optional and only affect scanner and drive redirection.

### Restoring secrets

From the removable backup containing `ssh/` and `gpg/`:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cp ssh/* ~/.ssh/
chmod 600 ~/.ssh/*
chmod 644 ~/.ssh/*.pub ~/.ssh/known_hosts

gpg --import gpg/public.pgp
gpg --pinentry-mode loopback --import gpg/private.pgp
fpr=$(gpg --list-secret-keys --with-colons \
  | awk -F: '/^sec:/{w=1;next} /^fpr:/&&w{print $10;w=0}')
echo "$fpr:6:" | gpg --import-ownertrust

ssh-add ~/.ssh/id_rsa
git clone <your-password-store-repo> ~/.password-store
```

The explicit permissions matter when restoring from a vfat drive. Verify GPG
encryption and decryption before trusting the restored password store.

A `pass` store is personal, so no repository is named here. Substitute your
own, or `pass init <gpg-id>` to start an empty one.

The shell does not load SSH keys into the agent — it only points at it. Add this
to `~/.ssh/config` so a key is added on first use and stays cached for the
session, instead of every new shell paying for an `ssh-add`:

```
Host *
    AddKeysToAgent yes
```

`~/.ssh` is deliberately not managed by `rcm`: `rcup` would symlink files back
into this repository, and the `cp ssh/* ~/.ssh/` above would then write through
those symlinks. Keep it machine-local.

## Customization

The configuration is designed to be modular and easily customizable:

- **Colors**: All themes use Catppuccin - modify `config/hypr/conf/mocha.lua` (Hyprland),
  `config/hypr/mocha.conf` (hyprlock), and related theme files
- **Keybindings**: Hyprland bindings live in `config/hypr/conf/binds.lua`
- **Applications**: Each app configuration is self-contained in `config/`
- **Scripts**: Custom utilities in `bin/` can be modified or extended

## Requirements

- **Arch Linux** (primary target) or **Debian 12** (headless LXC)
- **Hyprland** compositor (Arch desktop)
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
