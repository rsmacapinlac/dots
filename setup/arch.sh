#!/bin/bash
# Core Arch workstation installer.
#
# This is the post-Archinstall phase launched by setup/start.sh. It builds a
# complete, usable Hyprland desktop. Optional software belongs in
# setup/applications.sh.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=setup/lib/arch-common.sh
source "$SCRIPT_DIR/lib/arch-common.sh"

update_package_mirrors() {
    log_info "Updating package mirrors..."
    if ! command -v reflector &>/dev/null; then
        sudo pacman -S --needed --noconfirm reflector
    fi

    if sudo reflector \
        --country 'United States,Canada' \
        --latest 5 \
        --protocol https \
        --sort score \
        --save /etc/pacman.d/mirrorlist 2>/dev/null; then
        log_success "Package mirrors updated"
    else
        log_warning "Reflector failed; retaining the existing mirror list"
    fi
}

initial_setup() {
    configure_pacman_parallel_downloads
    sudo pacman -Sy --noconfirm
    update_package_mirrors
    sudo pacman -S --needed --noconfirm openssh git
}

install_lua54_compatibility() {
    if pacman -Q lua54 &>/dev/null; then
        return 0
    fi

    log_info "Creating the lua54 compatibility package required by libinput..."
    local build_dir
    build_dir=$(mktemp -d -t lua54-build.XXXXXX)
    cat > "$build_dir/PKGBUILD" <<'PKGEOF'
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
    (
        cd "$build_dir"
        makepkg -si --noconfirm
    )
    rm -rf "$build_dir"
}

install_core_packages() {
    log_info "Installing core system and terminal packages..."
    yay -Rns --noconfirm ksshaskpass polkit-gnome 2>/dev/null || true

    yay_install \
        base-devel \
        linux-headers \
        linux-firmware \
        mesa \
        vulkan-icd-loader \
        curl \
        git \
        rsync \
        openssh \
        zsh \
        mise \
        neovim \
        python-pynvim \
        tmux \
        ranger \
        ripgrep \
        fd \
        fzf \
        lazygit \
        make \
        xclip \
        wl-clipboard \
        htop \
        btop \
        tldr \
        fastfetch \
        jq \
        socat \
        pinentry \
        polkit-kde-agent
}

configure_user_shell() {
    log_info "Configuring Zsh..."
    sudo chsh -s /bin/zsh "$USER"

    if [[ ! -d $HOME/.oh-my-zsh ]]; then
        local installer
        installer=$(mktemp -t oh-my-zsh.XXXXXX.sh)
        curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$installer"
        sh "$installer" --unattended
        rm -f "$installer"
    else
        log_info "Oh My Zsh is already installed"
    fi
}

install_hardware_support() {
    log_info "Installing hardware and system integration..."
    yay_install \
        networkmanager \
        network-manager-applet \
        bluez \
        bluez-utils \
        blueman \
        bolt \
        pipewire \
        pipewire-pulse \
        wireplumber \
        brightnessctl \
        pamixer \
        playerctl \
        ddcutil \
        cups \
        cups-pdf \
        system-config-printer \
        avahi \
        nss-mdns \
        upower \
        udisks2

    sudo usermod -a -G lp "$USER"
}

setup_dotfiles() {
    log_info "Installing dotfiles..."
    yay -Rns --noconfirm rcm-git 2>/dev/null || true
    yay_install rcm
    mkdir -p "$HOME/workspace"

    local dots_ref=${DOTS_REF:-main}
    if [[ ! -d $HOME/workspace/dots ]]; then
        git clone --branch "$dots_ref" \
            https://github.com/rsmacapinlac/dots.git \
            "$HOME/workspace/dots"
        git -C "$HOME/workspace/dots" remote set-url --push \
            origin git@github.com:rsmacapinlac/dots.git
    else
        log_info "Dots repository already exists; leaving user changes untouched"
    fi

    env RCRC="$HOME/workspace/dots/rcrc" rcup -f
}

configure_terminal_tools() {
    log_info "Configuring tmux and Mise-backed tools..."
    export PATH="$HOME/.local/bin:$PATH"
    "$HOME/workspace/dots/bin/install-mise-tools"

    if [[ ! -d $HOME/.tmux/plugins/tpm ]]; then
        git clone --depth 1 https://github.com/tmux-plugins/tpm.git \
            "$HOME/.tmux/plugins/tpm"
    fi
}

install_core_security() {
    log_info "Installing core credential tools..."
    yay_install \
        gnupg \
        gnome-keyring \
        libsecret \
        pass \
        pass-otp \
        zbar

    if [[ ! -f $HOME/.mozilla/native-messaging-hosts/passff.json ]]; then
        curl -fsSL \
            https://codeberg.org/PassFF/passff-host/releases/download/latest/install_host_app.sh \
            | bash -s -- firefox
    fi

    local gpg_conf="$HOME/.gnupg/gpg-agent.conf"
    mkdir -p "$HOME/.gnupg"
    chmod 700 "$HOME/.gnupg"
    if [[ -L $gpg_conf ]]; then
        cp "$gpg_conf" "$gpg_conf.tmp"
        mv "$gpg_conf.tmp" "$gpg_conf"
    fi
    if ! grep -q '^pinentry-program ' "$gpg_conf" 2>/dev/null; then
        echo "pinentry-program $HOME/.bin/pinentry-wrapper" >> "$gpg_conf"
    fi
    gpgconf --kill gpg-agent 2>/dev/null || true

    log_warning "SSH/GPG keys and the password store are not restored automatically."
    log_warning "Follow the manual restore instructions in README.md after rebooting."
}

configure_locale() {
    log_info "Configuring the UTF-8 locale..."
    sudo sed -i 's/^#\?en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    sudo locale-gen
    echo 'LANG=en_US.UTF-8' | sudo tee /etc/locale.conf >/dev/null
}

install_browsers() {
    log_info "Installing core browsers..."
    yay_install firefox qutebrowser
}

install_hyprland() {
    log_info "Installing the Hyprland desktop..."
    yay_install \
        hyprland \
        uwsm \
        mako \
        libnotify \
        kitty \
        rofi \
        waybar \
        xdg-desktop-portal-hyprland \
        qt5-wayland \
        qt6-wayland \
        grim \
        slurp \
        hyprshot \
        hyprpaper \
        hyprpicker \
        hypridle \
        hyprlock \
        hyprcursor \
        hyprpolkitagent

    sudo mkdir -p /etc/systemd/logind.conf.d
    sudo tee /etc/systemd/logind.conf.d/lid.conf >/dev/null <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
EOF
}

install_fonts() {
    log_info "Installing desktop fonts..."
    yay_install \
        noto-fonts \
        noto-fonts-cjk \
        noto-fonts-emoji \
        woff2-font-awesome \
        ttf-fantasque-sans-mono \
        ttf-fantasque-nerd \
        ttf-ia-writer \
        ttf-ibmplex-mono-nerd \
        ttf-nerd-fonts-symbols \
        ttf-nerd-fonts-symbols-mono \
        ttf-dejavu-nerd \
        ttf-jetbrains-mono-nerd
}

install_file_managers() {
    log_info "Installing file managers and preview support..."
    yay_install \
        atool \
        elinks \
        ffmpegthumbnailer \
        highlight \
        imagemagick \
        lynx \
        mediainfo \
        transmission-cli \
        ueberzug \
        w3m \
        nautilus \
        sushi \
        gvfs \
        gvfs-smb
}

install_greeter() {
    log_info "Installing and configuring greetd..."
    sudo systemctl disable sddm 2>/dev/null || true
    sudo systemctl stop sddm 2>/dev/null || true
    yay -Rns --noconfirm sddm 2>/dev/null || true
    yay_install greetd

    sudo mkdir -p /etc/greetd
    sudo tee /etc/greetd/config.toml >/dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "uwsm start -- start-hyprland"
user = "greeter"

[initial_session]
command = "uwsm start -- start-hyprland"
user = "$USER"
EOF
    sudo systemctl enable greetd
}

configure_timeshift() {
    log_info "Installing Timeshift's pacman snapshot hook..."
    yay_install timeshift-autosnap

    # timeshift-autosnap is a PreTransaction hook on Upgrade: it asks Timeshift
    # for a snapshot before every `pacman -Syu`. Timeshift itself needs a config
    # to do anything, and neither the Archinstall profile nor this installer used
    # to create one -- so the hook ran on every upgrade and quietly did nothing.
    local conf=/etc/timeshift/timeshift.json
    if [[ -f $conf ]]; then
        log_info "Timeshift is already configured; leaving $conf untouched"
        return 0
    fi

    local fstype uuid
    fstype=$(findmnt -no FSTYPE / 2>/dev/null || true)
    uuid=$(findmnt -no UUID / 2>/dev/null || true)

    if [[ $fstype != btrfs ]]; then
        log_warning "Root is $fstype, not btrfs; skipping Timeshift setup."
        log_warning "Configure Timeshift by hand if you want snapshots."
        return 0
    fi
    if [[ -z $uuid ]]; then
        log_warning "Could not determine the root filesystem UUID; skipping Timeshift setup."
        return 0
    fi

    # BTRFS mode requires the Ubuntu-style @ / @home layout, which the
    # Archinstall profiles create. Scheduled snapshots stay off: the point here
    # is a snapshot before package upgrades, which the hook triggers.
    log_info "Configuring Timeshift in BTRFS mode on $uuid..."
    sudo mkdir -p /etc/timeshift
    sudo tee "$conf" >/dev/null <<EOF
{
  "backup_device_uuid" : "$uuid",
  "parent_device_uuid" : "",
  "do_first_run" : "false",
  "btrfs_mode" : "true",
  "include_btrfs_home_for_backup" : "false",
  "include_btrfs_home_for_restore" : "false",
  "stop_cron_emails" : "true",
  "schedule_monthly" : "false",
  "schedule_weekly" : "false",
  "schedule_daily" : "false",
  "schedule_hourly" : "false",
  "schedule_boot" : "false",
  "count_monthly" : "2",
  "count_weekly" : "3",
  "count_daily" : "5",
  "count_hourly" : "6",
  "count_boot" : "5",
  "date_format" : "%Y-%m-%d %H:%M:%S",
  "exclude" : [],
  "exclude-apps" : []
}
EOF
    log_success "Timeshift configured; upgrades will snapshot first"
}

enable_core_services() {
    log_info "Enabling core services..."
    sudo systemctl enable NetworkManager
    sudo systemctl enable bluetooth
    sudo systemctl enable bolt.service 2>/dev/null || true
    sudo systemctl enable cups.service
    sudo systemctl enable avahi-daemon.service

    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable ssh-agent.service 2>/dev/null || true
    systemctl --user enable gnome-keyring-daemon 2>/dev/null || true

    # The session runs under uwsm, which activates graphical-session.target, so
    # these packaged units start and stay supervised. Without a session manager
    # the target never activates and enabling them would be a no-op -- that is
    # exactly how hypridle silently never ran. conf/autostart.lua must not also
    # exec these, or each gets a second, unsupervised copy.
    local unit
    for unit in hypridle hyprpaper waybar mako hyprpolkitagent; do
        systemctl --user enable "$unit.service" 2>/dev/null \
            || log_warning "Could not enable $unit.service"
    done
}

main() {
    log_info "Starting the core Arch workstation installation..."
    begin_arch_install

    initial_setup
    install_aur_helper
    install_lua54_compatibility
    upgrade_system

    install_core_packages
    configure_user_shell
    install_hardware_support
    setup_dotfiles
    configure_terminal_tools
    configure_locale
    install_browsers
    install_core_security
    install_hyprland
    install_fonts
    install_file_managers
    configure_timeshift
    install_greeter
    enable_core_services
    remove_build_dependencies

    log_success "Core workstation installation completed."
    log_info "Reboot to start the Hyprland desktop through greetd."
    log_info "Install optional software afterwards with setup/applications.sh."
}

main "$@"
