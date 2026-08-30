#!/bin/bash
#
# Workstation Builder - RSM's Unified Installation Script
#
# This script always installs the latest available versions:
# - Arch/AUR packages: automatically latest via yay/pacman
# - GitHub AppImages/releases: fetched via GitHub API (latest release)
# - Git repositories: shallow clones from main/master branch (latest commit)
# - npm packages: installed globally with latest version
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PI_SUBAGENTS_PACKAGE="npm:@tintinweb/pi-subagents"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Wrapper for yay to prevent hanging on interactive AUR prompts.
#
# Deliberately without --removemake. That flag uninstalls build dependencies
# after every transaction, and this script runs 30 of them across 16 AUR
# packages, so shared build deps — go alone is ~250 MB — get downloaded,
# installed and removed over and over. remove_build_dependencies() sweeps them
# once at the end instead.
yay_install() {
    refresh_runtime_path
    yay -S --needed --noconfirm --answerdiff None --answerclean None "$@"
}

# Pick up PATH entries added by packages installed during this run.
#
# Packages can drop PATH additions into /etc/profile.d, but those files are
# sourced only by login shells. This script's shell logged in before those
# packages existed, so its PATH stays stale for the whole run and every child
# it spawns — makepkg included — inherits the stale copy.
#
# perl is the one that bites. It installs pod2man into /usr/bin/core_perl and
# adds that directory through /etc/profile.d/perlbin.sh, so any AUR build that
# generates man pages dies with "pod2man: command not found". It only happens on
# a machine where perl was installed during the same session — which is every
# fresh install, and never a re-run.
#
# Found via lbdb, which has since been dropped as unused. Kept because the
# problem is general to any AUR package that builds documentation.
#
# Only logs when it actually changes something, so calling it from yay_install
# on every transaction stays quiet.
refresh_runtime_path() {
    local dir
    for dir in /usr/bin/core_perl /usr/bin/vendor_perl /usr/bin/site_perl; do
        if [[ -d $dir && ":$PATH:" != *":$dir:"* ]]; then
            PATH="$PATH:$dir"
            export PATH
            log_info "Added $dir to PATH (installed during this run)"
        fi
    done
}

# Enable parallel package downloads.
#
# pacman ships this commented out, and archinstall's own default is 0, which its
# help text describes as "allows only 1 download at a time". This script then
# downloads several GB across hundreds of packages, all serially. Enabling it
# early means every step afterwards benefits, including yay, which shells out to
# pacman for repo packages.
configure_pacman_parallel_downloads() {
    local conf=/etc/pacman.conf

    if grep -qE '^[[:space:]]*ParallelDownloads' "$conf"; then
        log_info "ParallelDownloads already enabled"
        return 0
    fi

    log_info "Enabling parallel package downloads..."
    if grep -qE '^[[:space:]]*#[[:space:]]*ParallelDownloads' "$conf"; then
        sudo sed -i 's/^[[:space:]]*#[[:space:]]*ParallelDownloads.*/ParallelDownloads = 5/' "$conf"
    else
        sudo sed -i '/^\[options\]/a ParallelDownloads = 5' "$conf"
    fi

    if grep -qE '^[[:space:]]*ParallelDownloads' "$conf"; then
        log_success "ParallelDownloads enabled"
    else
        log_warning "Could not enable ParallelDownloads; downloads will be serial"
    fi
}

# Remove build dependencies left behind by AUR builds.
#
# The counterpart to dropping --removemake above: build deps are installed once
# and swept once, rather than churned on every transaction.
remove_build_dependencies() {
    log_info "Removing orphaned build dependencies..."
    if yay -Yc --noconfirm 2>/dev/null; then
        log_success "Build dependencies cleaned up"
    else
        log_info "Nothing to clean up"
    fi
}

# Configure user-level npm globals so Pi packages do not require sudo.
configure_npm_user_prefix() {
    if ! command -v npm &> /dev/null; then
        log_warning "npm not found, skipping npm user prefix setup"
        return 0
    fi

    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global"
    export PATH="$HOME/.npm-global/bin:$PATH"
}

# Check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Run as a regular user with sudo privileges."
        exit 1
    fi
}

# Run the whole install without repeated password prompts.
#
# A full run takes 45-90 minutes and makes dozens of sudo calls directly, plus
# however many yay and makepkg invoke on their own. sudo's timestamp_timeout
# defaults to 15 minutes, so without this the install stops to ask for a
# password several times — usually mid-transaction, where it is easy to miss and
# easy to leave the machine idle for hours waiting on a prompt nobody saw.
#
# You authenticate once, here, to install the rule. It grants NOPASSWD: ALL to
# the invoking user only, and only for the length of the run.
#
# A leftover rule is a standing privilege escalation, so removal has three
# independent layers:
#   1. the EXIT trap, for normal and signalled exits
#   2. a background watcher, because a trap does not run on SIGKILL
#   3. removal at startup, in case a previous run lost both of the above
SUDO_NOPASSWD_FILE="/etc/sudoers.d/99-dots-setup"
SUDO_WATCHER_PID=""

enable_passwordless_sudo() {
    log_info "Enabling passwordless sudo for the duration of this run..."

    if ! sudo -v; then
        log_error "Cannot obtain sudo privileges for $USER."
        exit 1
    fi

    # Layer 3: clear anything a previous run left behind.
    sudo rm -f "$SUDO_NOPASSWD_FILE"

    local tmp
    tmp="$(mktemp)"
    printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$USER" > "$tmp"

    # Validate before installing. A malformed file in /etc/sudoers.d breaks sudo
    # for every user, and discovering that on a half-built machine with no
    # working sudo is a genuinely bad place to be.
    if ! sudo visudo -c -f "$tmp" > /dev/null; then
        rm -f "$tmp"
        log_error "Refusing to install a sudoers file that does not validate."
        exit 1
    fi

    sudo install -m 0440 -o root -g root "$tmp" "$SUDO_NOPASSWD_FILE"
    rm -f "$tmp"

    # Layer 2: the watcher outlives an abnormal exit and cleans up. $$ inside
    # the subshell is still this script's PID. The rule is still in force while
    # this runs, so its own sudo needs no password.
    (
        while kill -0 "$$" 2>/dev/null; do sleep 5; done
        sudo -n rm -f "$SUDO_NOPASSWD_FILE" 2>/dev/null
    ) &
    SUDO_WATCHER_PID=$!

    log_success "Passwordless sudo active; removed automatically when this script exits"
}

disable_passwordless_sudo() {
    if [[ -n $SUDO_WATCHER_PID ]]; then
        kill "$SUDO_WATCHER_PID" 2>/dev/null || true
        SUDO_WATCHER_PID=""
    fi

    if [[ -e $SUDO_NOPASSWD_FILE ]]; then
        if sudo -n rm -f "$SUDO_NOPASSWD_FILE" 2>/dev/null; then
            log_info "Passwordless sudo rule removed."
        else
            log_warning "Could not remove $SUDO_NOPASSWD_FILE — remove it manually:"
            log_warning "    sudo rm -f $SUDO_NOPASSWD_FILE"
        fi
    fi
}

# Detect Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=${ID:-}
        DISTRO_VERSION=${VERSION_ID:-}
        log_info "Detected distribution: ${PRETTY_NAME:-$DISTRO}"
    else
        log_error "Cannot detect Linux distribution"
        exit 1
    fi
}


# Update package mirrors for faster downloads
update_package_mirrors() {
    log_info "Updating package mirrors for faster downloads..."

    # Install reflector if not present
    if ! command -v reflector &> /dev/null; then
        sudo pacman -S --needed --noconfirm reflector
    fi

    # Try to update mirrorlist with reflector
    # If it fails (common issue with Python dependencies), continue anyway
    if sudo reflector \
        --country 'United States,Canada' \
        --latest 5 \
        --protocol https \
        --sort score \
        --save /etc/pacman.d/mirrorlist 2>/dev/null; then
        log_success "Package mirrors updated"
    else
        log_warning "Reflector failed, skipping mirror update"
        log_info "You may want to manually update /etc/pacman.d/mirrorlist if downloads are slow"
    fi
}

# Initial setup function for SSH and GPG
initial_setup() {
    log_info "Update system and install minimal packages required for initial setup..."

    # Enable parallel downloads before anything is fetched.
    configure_pacman_parallel_downloads

    # Update system first
    sudo pacman -Sy --noconfirm

    # Update mirrors early to ensure fast package downloads
    update_package_mirrors

    # Install minimal packages needed for initial setup
    sudo pacman -S --needed --noconfirm openssh git

    # SSH and GPG key restore deliberately does NOT happen here.
    #
    # This script builds the machine and must run unattended — in a VM, on a
    # fresh laptop, before the key backup is at hand. Secrets are restored by
    # hand afterwards; see the notes at the end of configure_security().

    log_success "Initial setup completed"
}

# Install base system packages (system/base/packages)
install_base_packages() {
    log_info "Installing base system packages..."
    
    # Remove conflicting polkit packages
    yay -Rns --noconfirm ksshaskpass polkit-gnome 2>/dev/null || true
    
    # Install base system packages
    yay_install \
        htop \
        polkit-kde-agent \
        curl \
        rsync \
        base-devel \
        linux-headers \
        zsh \
        nodejs \
        npm \
        fastfetch \
        autorandr \
        syncthing \
        cups \
        cups-pdf \
        system-config-printer \
        avahi \
        nss-mdns \
        pinentry
    
    # Add user to lp group for printer access
    sudo usermod -a -G lp "$USER"
    
    log_success "Base system packages installed"
}

# Configure user shell (system/base/users)
configure_user_shell() {
    log_info "Configuring user shell..."
    
    # Change user shell to zsh
    sudo chsh -s /bin/zsh "$USER"
    
    # Remove existing oh-my-zsh if present
    rm -rf ~/.oh-my-zsh 2>/dev/null || true

    # Download and install latest oh-my-zsh from master branch
    log_info "Installing latest oh-my-zsh..."
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /tmp/install.sh
    sh /tmp/install.sh --unattended
    
    log_success "User shell configured"
}

# Configure system services (system/base/services)
configure_system_services() {
    log_info "Configuring system services..."
    
    # Install system services packages
    yay_install \
        blueman \
        bluez \
        bluez-utils \
        pipewire \
        pipewire-pulse \
        wireplumber
    
    log_success "System services configured"
}

# Security configuration (system/security)
configure_security() {
    log_info "Configuring security tools..."
    
    mkdir -p ~/workspace

    # The password store is NOT cloned here. It is a private repository, so it
    # needs an SSH key, which this script must not depend on. It is cloned by
    # hand after the keys are restored; see the notes at the end of this
    # function.

    # Install Bitwarden CLI via npm (avoids nodejs-lts-jod conflict with nodejs)
    sudo npm install -g @bitwarden/cli

    # Install pass password manager and extensions
    yay_install \
        bitwarden \
        pass \
        pass-otp \
        wl-clipboard \
        zbar \
        wireguard-tools \
        openresolv
    
    # Install PassFF host app for Firefox integration
    if [[ ! -f "$HOME/.mozilla/native-messaging-hosts/passff.json" ]]; then
        curl -sSL https://codeberg.org/PassFF/passff-host/releases/download/latest/install_host_app.sh | bash -s -- firefox
    fi
    
    log_success "Security configuration completed"

    # Manual secret restore, run from the key backup directory (ssh/ and gpg/).
    # Two things here are easy to get wrong and fail in confusing ways:
    #
    #   1. The backup lives on vfat, which reports every file as mode 755. ssh
    #      refuses a private key that is group- or world-readable, so every
    #      private key needs chmod 600 — not just id_rsa. The ansible and
    #      terraform keys are silently unusable otherwise.
    #      (The glob skips the macOS ._* resource forks on that drive already,
    #      since globs do not match leading dots.)
    #
    #        mkdir -p ~/.ssh && chmod 700 ~/.ssh
    #        cp ssh/* ~/.ssh/
    #        chmod 600 ~/.ssh/*
    #        chmod 644 ~/.ssh/*.pub ~/.ssh/known_hosts
    #
    #   2. Piping "5\ny" into `gpg --edit-key <id> trust` reports success but
    #      records nothing. gpg then refuses to encrypt with "Unusable public
    #      key" and pass is broken. Use --import-ownertrust (6 = ultimate):
    #
    #        gpg --import gpg/public.pgp
    #        gpg --pinentry-mode loopback --import gpg/private.pgp
    #        fpr=$(gpg --list-secret-keys --with-colons \
    #                | awk -F: '/^sec:/{w=1;next} /^fpr:/&&w{print $10;w=0}')
    #        echo "$fpr:6:" | gpg --import-ownertrust
    #
    #   Then the password store, which needs the SSH key in an agent:
    #
    #        ssh-add ~/.ssh/id_rsa
    #        git clone git@github.com:rsmacapinlac/cautious-dollop.git ~/.password-store
    #
    #   Verify with a round trip before trusting it:
    #        echo hi | gpg -e -r <your-email> | gpg -d
    log_warning "NOTE: no keys, no password store. Restore them by hand — see the"
    log_warning "      notes at the end of configure_security() in setup/arch.sh."
}

# Configure Timeshift snapshots (system/snapshots)
configure_timeshift() {
    log_info "Configuring Timeshift integration..."

    # timeshift, grub-btrfs, inotify-tools and cronie are installed — and
    # grub-btrfsd.service and cronie.service enabled — by archinstall, from
    # disk_config.btrfs_options.snapshot_config = Timeshift with the Grub
    # bootloader. See setup/archinstall/ and archinstall's
    # Installer.setup_btrfs_snapshot(). Only the pacman pre-upgrade snapshot
    # hook is missing from that, so it is the only thing installed here.
    #
    # Note: `timeshift-gtk` and `grub-btrfsd` are NOT packages — the first is a
    # binary shipped in `timeshift`, the second a service unit shipped in
    # `grub-btrfs`. Listing them here aborted the whole bootstrap under `set -e`.
    yay_install timeshift-autosnap

    log_success "Timeshift integration configured"
}

# Install AUR helper (workstation/aur)
install_aur_helper() {
    log_info "Installing AUR helper (yay)..."
    
    # Check if yay is already installed
    if command -v yay &> /dev/null; then
        log_info "yay is already installed..."
        return 0 
    else
        log_info "yay not found, installing..."
    fi
    
    # makepkg needs base-devel, and it will not install it for us: Arch
    # PKGBUILDs never list base-devel members in makedepends by convention, so
    # `makepkg -s` cannot pull in what the PKGBUILD does not declare. On a
    # Minimal archinstall it is absent and the build dies with "Cannot find the
    # fakeroot binary" / "Cannot find the debugedit binary".
    #
    # install_base_packages also installs base-devel, but it runs later and uses
    # yay_install, which needs the yay being built here — so the prerequisite is
    # declared locally rather than fixed by reordering main().
    log_info "Installing build prerequisites (base-devel)..."
    sudo pacman -S --needed --noconfirm base-devel git

    # base-devel pulls perl; its bin dirs are not on this shell's PATH yet.
    refresh_runtime_path

    # Remove any existing yay build directory
    rm -rf /tmp/yay

    # Clone Yay repository
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    
    # Build and install Yay package
    cd /tmp/yay
    makepkg -f -s --noconfirm
    sudo pacman -U --noconfirm yay-*.pkg.tar.zst
    
    # Remove temporary directory
    rm -rf /tmp/yay
    cd ~
    
    log_success "AUR helper installed"
}

# Configure GnuPG pinentry (workstation/gnupg)
configure_gnupg() {
    log_info "Configuring GnuPG pinentry..."

    local conf="$HOME/.gnupg/gpg-agent.conf"

    mkdir -p "$HOME/.gnupg"
    chmod 700 "$HOME/.gnupg"

    # Break symlink so the injected pinentry path doesn't land in the dotfiles repo
    if [[ -L "$conf" ]]; then
        cp "$conf" "$conf.tmp" && mv "$conf.tmp" "$conf"
    fi

    if ! grep -q "^pinentry-program " "$conf" 2>/dev/null; then
        echo "pinentry-program $HOME/.bin/pinentry-wrapper" >> "$conf"
    fi

    gpgconf --kill gpg-agent 2>/dev/null || true
    log_success "GnuPG configured"
}

# Setup dotfiles (workstation/dotfiles)
setup_dotfiles() {
    log_info "Setting up dotfiles..."
    
    # Install rcm from AUR first (needed for workstation role)
    # Remove conflicting rcm-git package if present
    yay -Rns --noconfirm rcm-git 2>/dev/null || true
    yay_install rcm
    
    # Ensure workspace directory exists
    mkdir -p "$HOME/workspace"
    
    # Clone dots repository (skip if already exists).
    #
    # Fetch over HTTPS: dots is public, so this needs no credentials and works
    # before any SSH key is restored. The push remote is set to SSH afterwards
    # so committing from this machine still works once keys are in place.
    if [[ ! -d "$HOME/workspace/dots" ]]; then
        git clone https://github.com/rsmacapinlac/dots.git "$HOME/workspace/dots"
        git -C "$HOME/workspace/dots" remote set-url --push origin git@github.com:rsmacapinlac/dots.git
    else
        log_info "Dots repository already exists, skipping clone"
    fi
    
    # Setup rcup with github dotfiles
    env RCRC="$HOME/workspace/dots/rcrc" rcup -f
    
    log_success "Dotfiles setup completed"
}

# Install development packages (development/packages)
install_development_packages() {
    log_info "Installing development packages..."
    
    yay_install \
        ruby \
        ruby-erb \
        ripgrep \
        fd \
        fzf \
        xclip \
        python-pynvim \
        esptool \
        lazygit \
        go \
        make
    
    # Install Go development tools
    #log_info "Installing Go development tools..."
    
    # Install essential Go tools
    #go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
    #go install golang.org/x/tools/cmd/goimports@latest  
    #go install golang.org/x/tools/cmd/godoc@latest
    
    log_success "Development packages and Go tools installed"
}

# Install development editors (development/editors)
install_development_editors() {
    log_info "Installing development editors..."
    
    # Install editors from official repos
    yay_install \
        neovim \
    
    # Install editors from AUR
    yay_install \
        cursor-bin \
        claude-code

    log_success "Development editors installed"
}

# Setup development tools (development/tools)
setup_development_tools() {
    log_info "Setting up development tools..."
    
    yay_install \
        tmux 

    # Install RVM
    if [[ ! -d "$HOME/.rvm" ]]; then
        curl -sSL https://get.rvm.io | bash
    fi
    
    # Clone TPM repository for tmux
    if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        git clone --depth 1 https://github.com/tmux-plugins/tpm.git "$HOME/.tmux/plugins/tpm"
    fi
    
    log_success "Development tools setup completed"
}

# Install applications - browsers (applications/browser)
install_browsers() {
    log_info "Installing browsers..."
    
    # chromium is here as a web app host, not as a browsing browser: --app=
    # windows are a Chromium-only feature, Firefox dropped SSB support, and
    # qutebrowser has no equivalent. set_default_web_browser() does not consider
    # it, so installing it does not change the http/https handler.
    yay_install \
        firefox \
        qutebrowser \
        chromium \
        yt-dlp \
        mpv
    
    log_success "Browsers installed"
}

# Install applications - productivity (applications/productivity)
install_productivity_apps() {
    log_info "Installing productivity applications..."
    
    # Install from AUR (--asexplicit prevents pulling optional deps like qt5-webengine for zoom)
    yay_install \
        gnucash \
        krdc \
        nextcloud-client \
        obsidian \
        slack-desktop \
        telegram-desktop \
        todoist-appimage \
        zoom \
        timer-bin \
        speech-dispatcher

    log_success "Productivity applications installed"
}

# Install applications - media (applications/media)
install_media_apps() {
    log_info "Installing media applications..."
    
    # Remove conflicting packages
    yay -Rns --noconfirm totem totem-plugins 2>/dev/null || true
    
    yay_install \
        vlc \
        vlc-plugins-all \
        libao \
        mpd \
        ncmpcpp \
        mpc \
        python-requests \
        beets \
        python-pyacoustid \
        python-discogs-client \
        rmpc \
        handbrake \
        obs-studio \
        v4l2loopback-dkms

    # Persist and load v4l2loopback for OBS Virtual Camera
    echo "v4l2loopback" | sudo tee /etc/modules-load.d/v4l2loopback.conf > /dev/null
    sudo modprobe v4l2loopback 2>/dev/null || true

    # Configure a UTF-8 system locale. Prefer LANG in /etc/locale.conf;
    # avoid setting LC_ALL globally because it overrides category-specific locales.
    sudo sed -i 's/^#\?en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    sudo locale-gen
    echo "LANG=en_US.UTF-8" | sudo tee /etc/locale.conf > /dev/null
    
    # Disable system MPD service in favor of user service (already in the dot files)
    sudo systemctl stop mpd.service 2>/dev/null || true
    sudo systemctl disable mpd.service 2>/dev/null || true
    
    log_success "Media applications installed"
}

# Install applications - steam (applications/steam)
install_steam() {
    log_info "Installing Steam..."
    
    # Enable multilib repository
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
        yay -Sy --noconfirm --answerdiff None --answerclean None
    fi
    
    # Install Steam and dependencies
    yay_install \
        steam \
        ttf-liberation \
        lib32-mesa \
        lib32-vulkan-icd-loader \
        lib32-alsa-plugins \
        lib32-pulseaudio \
        lib32-gtk3 \
        lib32-glibc \
        lib32-gcc-libs
    
    log_success "Steam installed"
}

# Install applications - mail (applications/mail)
install_mail_client() {
    log_info "Installing terminal mail client..."
    
    # Install mail client packages
    yay_install \
        neomutt \
        isync \
        msmtp \
        gnupg \
        notmuch \
        urlscan \
        lynx \
        w3m \
        imagemagick \
        kitty-terminfo \
        feh \
        zathura \
        zathura-pdf-mupdf \
        zathura-ps \
        zathura-djvu \
        zathura-cb \
        libreoffice-still \
        unzip \
        unrar \
        p7zip
    
    log_success "Terminal mail client installed"
}

# Setup flatpak (applications/flatpak)
#setup_flatpak() {
#    log_info "Setting up Flatpak..."
#    
#    sudo pacman -S --needed --noconfirm flatpak
#    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
#    
#    log_success "Flatpak setup completed"
#}

# Install desktop - Hyprland (desktop/hyprland)
install_hyprland() {
    log_info "Installing Hyprland desktop environment..."
    
    # Install core Hyprland packages
    yay_install \
        hyprland \
        mako \
        libnotify \
        kitty \
        uwsm \
        rofi-wayland \
        xdg-desktop-portal-hyprland \
        qt5-wayland \
        qt6-wayland \
        grim \
        slurp \
        hyprshot \
        wl-clipboard \
        swww \
        gnome-keyring \
        libsecret \
        networkmanager \
        network-manager-applet \
        brightnessctl \
        pavucontrol \
        waybar \
        hyprpaper \
        hyprpicker \
        hypridle \
        hyprlock \
        hyprcursor \
        hyprpolkitagent \
        socat \
        jq \
        ttf-fantasque-sans-mono \
        ttf-fantasque-nerd
    
    # Configure logind to ignore lid close so Hyprland handles it via bindl
    sudo mkdir -p /etc/systemd/logind.conf.d
    sudo tee /etc/systemd/logind.conf.d/lid.conf > /dev/null << 'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
EOF
    # Do not restart systemd-logind here — it kills any live Hyprland session.
    log_info "logind lid config written; takes effect on next login or reboot"

    log_success "Hyprland desktop environment installed"
}

# Install greeter (desktop/greeter)
install_greeter() {
    log_info "Installing and configuring greetd..."
    
    # Disable and uninstall sddm if present
    sudo systemctl disable sddm 2>/dev/null || true
    sudo systemctl stop sddm 2>/dev/null || true
    yay -Rns --noconfirm sddm 2>/dev/null || true
    
    # Install greetd
    yay_install greetd
    
    # Create greetd configuration directory
    sudo mkdir -p /etc/greetd
    
    # Configure greetd to boot directly into Hyprland
    sudo tee /etc/greetd/config.toml > /dev/null << EOF
[terminal]
vt = 1

[default_session]
command = "start-hyprland"
user = "greeter"

[initial_session]
command = "start-hyprland"
user = "$USER"
EOF
    
    # Enable greetd service
    sudo systemctl enable greetd
    
    log_success "greetd installed and configured"
}

# Install desktop - fonts (desktop/fonts)
install_fonts() {
    log_info "Installing fonts..."
    
    yay_install \
        noto-fonts-cjk \
        ttf-font-awesome \
        ttf-ibmplex-mono-nerd \
        ttf-nerd-fonts-symbols \
        ttf-nerd-fonts-symbols-mono \
        ttf-dejavu-nerd \
        ttf-jetbrains-mono-nerd
    
    log_success "Fonts installed"
}

# Install desktop - terminals (desktop/terminal)
install_terminals() {
    log_info "Installing terminals..."
    
    yay_install \
        alacritty \
        kitty
    
    log_success "Terminals installed"
}

# Install desktop - file manager (desktop/filemanager)
install_file_manager() {
    log_info "Installing file managers..."
    
    # Install Ranger and dependencies
    yay_install \
        ranger \
        mc \
        atool \
        elinks \
        ffmpegthumbnailer \
        highlight \
        imagemagick \
        lynx \
        mediainfo \
        transmission-cli \
        ueberzug \
        w3m
    
    # Install Thunar and network browsing support
    yay_install \
        thunar \
        thunar-volman \
        gvfs \
        gvfs-smb \
        smbclient \
        cifs-utils \
        libsecret
    
    log_success "File managers installed"
}

# Install AI tools (ai)
install_ai_tools() {
    log_info "Installing AI tools..."

    # Install agent-browser: headless browser CLI for AI agents
    # https://github.com/vercel-labs/agent-browser
    # Install chromium system dependencies (--with-deps only supports apt/dnf/yum)
    # himalaya is in the official repo — install via pacman to avoid the AUR
    # version which pulls in webkit2gtk (compiled from source)
    sudo pacman -S --needed --noconfirm himalaya

    yay_install \
        gogcli \
        nss \
        libdrm \
        mesa \
        libxkbcommon \
        alsa-lib
    configure_npm_user_prefix
    npm install -g --allow-scripts=agent-browser agent-browser
    agent-browser install

    # Install Codex CLI: OpenAI's terminal coding agent
    # https://github.com/openai/codex
    yay_install openai-codex-bin

    # Install pi-coding-agent: minimalist AI coding agent
    # https://github.com/badlogic/pi-mono
    yay_install pi-coding-agent

    # Install pi-subagents: subagent orchestration package for Pi
    # https://pi.dev/packages/@tintinweb/pi-subagents
    if command -v pi &> /dev/null; then
        if pi install "$PI_SUBAGENTS_PACKAGE"; then
            log_success "Pi subagents package installed"
        else
            log_warning "Pi subagents package install failed"
        fi
    else
        log_warning "pi not found after install, skipping Pi subagents package"
    fi

    install_ai_desktop_apps

    log_success "AI tools installed"
}

# Install AI desktop apps (GUI companions to the terminal agents).
# Desktop-only: these are skipped on headless hosts such as the LXC setup.
install_ai_desktop_apps() {
    log_info "Installing AI desktop apps..."

    # Claude desktop: Anthropic's official Linux build, packaged in the AUR
    # https://claude.com/download
    yay_install claude-desktop

    # ChatGPT desktop (hosts the Codex view): OpenAI shipped an official Linux
    # build on 2026-08-11, but ships only .deb/.rpm and does not target Arch.
    # This AUR package repackages OpenAI's own .deb from their apt repo on
    # persistent.oaistatic.com, so it tracks the official binary and the same
    # version stream as the macOS cask. Non-fatal if it fails to build.
    yay_install chatgpt-desktop

    set_default_web_browser

    log_success "AI desktop apps installed"
}

# Pin the default http/https handler.
#
# chatgpt-desktop's .desktop entry claims x-scheme-handler/http and
# x-scheme-handler/https alongside its own x-scheme-handler/codex. With no
# explicit default set, xdg-open falls back to mimeinfo.cache, which is ordered
# alphabetically -- "chatgpt" sorts ahead of "firefox", so installing it
# silently makes ChatGPT the system browser. OAuth logins in Claude Desktop and
# ChatGPT Desktop then hand their login URL to ChatGPT instead of a browser and
# vanish with no error, which looks like the apps failing to spawn a browser.
#
# Only sets the default when one is not already pinned, so a deliberate choice
# is never overwritten on a rerun.
set_default_web_browser() {
    local current
    current=$(xdg-settings get default-web-browser 2>/dev/null)

    if [[ -n "$current" && "$current" != "chatgpt.desktop" ]]; then
        log_info "Default browser already set to $current, leaving it alone"
        return
    fi

    local browser
    for browser in firefox.desktop org.qutebrowser.qutebrowser.desktop; do
        if [[ -f "/usr/share/applications/$browser" ]]; then
            if xdg-settings set default-web-browser "$browser" 2>/dev/null; then
                log_success "Default browser set to $browser"
            else
                log_warning "Could not set $browser as the default browser"
            fi
            return
        fi
    done

    log_warning "No known browser installed; default http/https handler left unset"
}

# Install Raspberry Pi tools (rpi)
install_rpi_tools() {
    log_info "Installing Raspberry Pi tools..."

    yay_install rpi-imager

    # Override the system .desktop entry to use the wrapper script instead of pkexec,
    # which doesn't work on Wayland without passing WAYLAND_DISPLAY/XDG_RUNTIME_DIR.
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/com.raspberrypi.rpi-imager.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Version=1.5
Name=Raspberry Pi Imager
Comment=Tool for writing images to SD cards for Raspberry Pi
Icon=rpi-imager
Exec=rpi-imager %u
Categories=Utility;
StartupNotify=false
MimeType=x-scheme-handler/rpi-imager;application/vnd.raspberrypi.imager-manifest+json;
EOF

    log_success "Raspberry Pi tools installed"
}

# Install electronics/Arduino tools (arduino)
install_arduino_tools() {
    log_info "Installing Arduino tools..."

    # CLI + language server from official repos (terminal-first workflow, Neovim autocompletion)
    sudo pacman -S --needed --noconfirm arduino-cli arduino-language-server

    # Serial port access for board uploads (Arch uses the uucp group)
    sudo usermod -a -G uucp "$USER"

    log_success "Arduino tools installed"
    log_warning "Log out and back in for uucp group membership (serial uploads) to take effect"
}


# Hardware Verification Function
verify_virtualization_support() {
    log_info "Verifying virtualization support on T480s..."
    
    # T480s i7-8650U has confirmed VT-x support
    if ! grep -q "vmx" /proc/cpuinfo; then
        log_error "Intel VT-x not detected - this should not happen on T480s"
        log_error "Check BIOS settings: Security > Virtualization > Intel VT-x"
        return 1
    else
        log_success "Intel VT-x virtualization support confirmed"
    fi
    
    # Check KVM module availability
    if ! lsmod | grep -q kvm; then
        log_info "Loading KVM modules for Intel processor..."
        sudo modprobe kvm 2>/dev/null || log_warning "KVM module not available, skipping"
        sudo modprobe kvm_intel 2>/dev/null || log_warning "kvm_intel module not available, skipping"
    else
        log_success "KVM modules already loaded"
    fi
    
    # Verify hardware TPM 2.0 (T480s has hardware TPM)
    if [[ -e /dev/tpm0 ]] || [[ -e /dev/tpmrm0 ]]; then
        log_success "Hardware TPM detected on T480s"
    else
        log_warning "Hardware TPM not accessible - may need BIOS configuration"
        log_info "Check BIOS: Security > Security Chip > TPM 2.0"
    fi
    
    # Check available memory (T480s has 16GB)
    local total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_gb=$((total_mem / 1024 / 1024))
    log_info "Total system memory: ${total_gb}GB"
    
    if [ "$total_gb" -ge 12 ]; then
        log_success "Sufficient memory for Windows 11 VM (recommended: 6-8GB allocation)"
    else
        log_warning "Less than 16GB detected - VM performance may be limited"
    fi
    
    log_success "T480s virtualization verification completed"
}

# Install QEMU/KVM/libvirt (virtualization)
install_virtualization() {
    log_info "Installing virtualization software..."
    
    # Core virtualization packages
    yay_install \
        qemu-full \
        libvirt \
        virt-manager \
        edk2-ovmf \
        dnsmasq \
        bridge-utils \
        openbsd-netcat \
        swtpm \
        spice-vdagent \
        qemu-guest-agent \
        spice-gtk3 \
        usbredir \
        spice-protocol
    
    log_success "Virtualization packages installed"
}

# Configure QEMU/KVM/libvirt (virtualization) 
configure_virtualization() {
    log_info "Configuring virtualization environment for T480s..."
    
    # Add user to required groups
    sudo usermod -a -G libvirt "$USER"
    sudo usermod -a -G kvm "$USER"
    
    # Configure Intel nested virtualization (T480s supports this)
    log_info "Enabling Intel nested virtualization..."
    echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/kvm.conf
    
    # Configure libvirt network with T480s-appropriate settings
    sudo virsh net-autostart default 2>/dev/null || true
    
    # T480s-specific optimizations
    log_info "Applying T480s-specific optimizations..."
    
    # Configure CPU governor for better VM performance
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || true
    fi
    
    # Configure memory settings for 16GB system
    # Enable memory overcommit for better VM memory management
    echo 1 | sudo tee /proc/sys/vm/overcommit_memory
    
    # Set swappiness for better VM performance (T480s has NVMe SSD)
    echo 'vm.swappiness = 10' | sudo tee -a /etc/sysctl.d/99-vm-performance.conf
    
    log_success "T480s virtualization environment configured"
    log_info "Please log out and back in for group membership changes to take effect"
}

# Enable system services
enable_services() {
    log_info "Enabling system services..."
    
    # Enable NetworkManager (needed for network connectivity)
    sudo systemctl enable NetworkManager
    
    # Enable bluetooth service
    sudo systemctl enable bluetooth
    
    # Enable CUPS printing services
    sudo systemctl enable cups.service
    sudo systemctl enable avahi-daemon.service
    
    # Enable user MPD service
    systemctl --user daemon-reload
    systemctl --user enable mpd.service 2>/dev/null || true
    systemctl --user enable --now ssh-agent.service 2>/dev/null || true
    
    # Enable gnome-keyring 
    systemctl --user enable gnome-keyring-daemon 2>/dev/null || true

    # Enable Syncthing user service
    systemctl --user enable syncthing.service 2>/dev/null || true
    
    # Enable hypridle service (screen lock and idle management)
    systemctl --user enable --now hypridle.service 2>/dev/null || true
    
    # Enable virtualization services
    sudo systemctl enable libvirtd.service
    sudo systemctl enable virtlogd.service
    sudo systemctl enable virtlockd.service
    
    log_success "System services enabled"
    log_warning "greetd display manager will start on next boot. Reboot to enter GUI environment."
}

# Main installation function
main() {
    log_info "Starting Workstation Builder installation..."
    
    check_not_root
    detect_distro
    
    if [[ "$DISTRO" != "arch" ]]; then
        log_error "This script only supports Arch Linux"
        exit 1
    fi

    # Authenticate once here so the rest of the run is unattended.
    trap disable_passwordless_sudo EXIT
    enable_passwordless_sudo

    # Run initial setup first
    initial_setup
    
    # maybe standardize on yay?
    install_aur_helper

    # Create lua54 shim — libinput 1.31.0 depends on it but no such package exists in repos/AUR
    if ! pacman -Q lua54 &>/dev/null; then
        log_info "Creating lua54 compatibility shim for libinput..."
        local lua54_tmp
        lua54_tmp=$(mktemp -d)
        cat > "$lua54_tmp/PKGBUILD" << 'PKGEOF'
pkgname=lua54
pkgver=5.4.0
pkgrel=1
pkgdesc="Lua 5.4 compatibility shim providing lua54 virtual package"
arch=('any')
provides=('lua54')
depends=('lua')
build() { true; }
package() { true; }
PKGEOF
        (cd "$lua54_tmp" && makepkg -si --noconfirm)
        rm -rf "$lua54_tmp"
        log_success "lua54 shim installed"
    fi

    # Full system upgrade to avoid dependency conflicts
    log_info "Performing full system upgrade..."
    yay -Syu --noconfirm --answerdiff None --answerclean None

    # system/base
    install_base_packages
    configure_user_shell
    configure_system_services
    
    # workstation
    setup_dotfiles
    configure_gnupg

    # development
    install_development_packages
    install_development_editors
    setup_development_tools
    
    # applications
    install_browsers
    install_productivity_apps
    install_media_apps
    install_steam
    install_mail_client
    # setup_flatpak

    # system/security
    configure_security
    
    # system/snapshots
    configure_timeshift

    # desktop
    install_hyprland
    install_greeter
    install_fonts
    install_terminals
    install_file_manager
    
    # ai tools
    install_ai_tools


    # raspberry pi
    install_rpi_tools

    # electronics / arduino
    install_arduino_tools

    # virtualization
    verify_virtualization_support
    install_virtualization
    configure_virtualization
    
    # Enable all services at the end
    enable_services

    # Sweep AUR build dependencies once, instead of after every transaction
    remove_build_dependencies
    
    log_success "Workstation Builder installation completed successfully!"
    log_info "Please reboot your system to ensure all changes take effect."
}

# Run main function only when executed directly.
# When sourced (e.g. to run a single install_* function), main is skipped.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
