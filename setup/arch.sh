#!/bin/bash
#
# Workstation Builder - Unified Installation Script
# Replaces the Ansible-based workflow with a direct bash script
# Usage: curl -fsSL https://raw.githubusercontent.com/USER/workstation-builder/main/install.sh | bash
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initial setup function for SSH and GPG
initial_setup() {
    log_info "Setting up SSH and GPG keys..."
    
    # Check for SSH setup
    if [[ -d ~/.ssh && -f ~/.ssh/id_rsa ]]; then
        log_info "SSH keys already exist, skipping SSH setup"
        SSH_SETUP_NEEDED=false
    else
        SSH_SETUP_NEEDED=true
        # Check for SSH folder
        if [[ -d "./ssh" ]]; then
            SSH_SOURCE="./ssh"
        else
            read -p "SSH folder not found in current directory. Please enter the path to your SSH folder: " SSH_SOURCE
            if [[ ! -d "$SSH_SOURCE" ]]; then
                log_error "SSH folder not found at $SSH_SOURCE"
                exit 1
            fi
        fi
    fi
    
    # Check for GPG setup
    if gpg --list-secret-keys 2>/dev/null | grep -q "sec"; then
        log_info "GPG keys already exist, skipping GPG setup"
        GPG_SETUP_NEEDED=false
    else
        GPG_SETUP_NEEDED=true
        # Check for GPG folder
        if [[ -d "./gpg" ]]; then
            GPG_SOURCE="./gpg"
        else
            read -p "GPG folder not found in current directory. Please enter the path to your GPG folder: " GPG_SOURCE
            if [[ ! -d "$GPG_SOURCE" ]]; then
                log_error "GPG folder not found at $GPG_SOURCE"
                exit 1
            fi
        fi
    fi
    
    # Setup SSH if needed
    if [[ "$SSH_SETUP_NEEDED" == true ]]; then
        mkdir -p ~/.ssh
        cp "$SSH_SOURCE"/* ~/.ssh/
        chmod 600 ~/.ssh/id_rsa
        log_success "SSH keys setup completed"
    fi
    
    # Setup SSH agent (needed for git clone operations)
    eval $(ssh-agent -s)
    ssh-add ~/.ssh/id_rsa
    
    # Install minimal packages needed for initial setup
    sudo pacman -Sy --noconfirm git
    
    # Setup GPG if needed
    if [[ "$GPG_SETUP_NEEDED" == true ]]; then
        gpg --batch --import "$GPG_SOURCE/public.pgp"
        gpg --batch --pinentry-mode loopback --import "$GPG_SOURCE/private.pgp"
        
        # Trust the imported key(s) automatically
        # Get the key fingerprint(s) and set ultimate trust
        gpg --list-secret-keys --with-colons | awk -F: '/^sec:/ {print $5}' | while read -r keyid; do
            echo -e "5\ny\n" | gpg --command-fd 0 --expert --edit-key "$keyid" trust quit
        done
        
        log_success "GPG keys setup and trusted"
    fi
    
    # Setup password repository 
    mkdir -p ~/workspace && cd ~/workspace
    if [[ ! -d ~/.password-store ]]; then
        git clone git@github.com:rsmacapinlac/cautious-dollop.git ~/.password-store
        log_success "Password store repository cloned"
    else
        log_info "Password store already exists, skipping clone"
    fi
    
    log_success "Initial setup completed"
}

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

# Check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Run as a regular user with sudo privileges."
        exit 1
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

# Install base system packages (system/base/packages)
install_base_packages() {
    log_info "Installing base system packages..."
    
    # Update system first
    sudo pacman -Sy --noconfirm
    
    # Remove conflicting polkit packages
    sudo pacman -Rns --noconfirm ksshaskpass polkit-gnome 2>/dev/null || true
    
    # Install base system packages
    sudo pacman -S --needed --noconfirm \
        polkit-kde-agent \
        curl \
        vim \
        base-devel \
        git \
        openssh \
        zsh \
        nodejs \
        npm \
        fastfetch \
        autorandr \
        syncthing \
        seahorse
    
    log_success "Base system packages installed"
}

# Configure user shell (system/base/users)
configure_user_shell() {
    log_info "Configuring user shell..."
    
    # Change user shell to zsh
    sudo chsh -s /bin/zsh "$USER"
    
    # Remove existing oh-my-zsh if present
    rm -rf ~/.oh-my-zsh 2>/dev/null || true
    
    # Download and install oh-my-zsh
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /tmp/install.sh
    sh /tmp/install.sh --unattended
    
    log_success "User shell configured"
}

# Configure system services (system/base/services)
configure_system_services() {
    log_info "Configuring system services..."
    
    # Install system services packages
    sudo pacman -S --needed --noconfirm \
        blueman \
        bluez \
        bluez-utils \
        pipewire \
        pipewire-pulse \
        wireplumber
    
    log_success "System services configured"
}

# Security configuration (system/security/pass)
configure_pass() {
    log_info "Configuring pass..."
    
    # Install pass password manager and extensions
    sudo pacman -S --needed --noconfirm \
        pass \
        pass-otp \
        wl-clipboard \
        zbar
    
    # Install PassFF host app for Firefox integration
    if [[ ! -f "$HOME/.mozilla/native-messaging-hosts/passff.json" ]]; then
        curl -sSL https://codeberg.org/PassFF/passff-host/releases/download/latest/install_host_app.sh | bash -s -- firefox
    fi
    
    log_success "Security configuration completed"
    log_warning "NOTE: Pass requires manual GPG key setup - run 'gpg --full-gen-key' then 'pass init <email>'"
}

# Install AUR helper (workstation/aur)
install_aur_helper() {
    log_info "Installing AUR helper (yay)..."
    
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

# Setup dotfiles (workstation/dotfiles)
setup_dotfiles() {
    log_info "Setting up dotfiles..."
    
    # Install rcm from AUR first (needed for workstation role)
    yay -S --needed --noconfirm rcm
    
    # Ensure workspace directory exists
    mkdir -p "$HOME/workspace"
    
    # Clone dots repository (skip if already exists)
    if [[ ! -d "$HOME/workspace/dots" ]]; then
        git clone git@github.com:rsmacapinlac/dots.git "$HOME/workspace/dots" || \
        git clone https://github.com/rsmacapinlac/dots.git "$HOME/workspace/dots"
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
    
    sudo pacman -S --needed --noconfirm \
        tmux \
        ruby \
        ruby-erb \
        ripgrep \
        fd \
        xclip \
        python-pynvim \
        lazygit
    
    log_success "Development packages installed"
}

# Install development editors (development/editors)
install_development_editors() {
    log_info "Installing development editors..."
    
    # Install editors from official repos
    sudo pacman -S --needed --noconfirm \
        neovim \
        vim
    
    # Install editors from AUR
    yay -S --needed --noconfirm \
        cursor-bin \
        claude-code

    
    log_success "Development editors installed"
}

# Setup development tools (development/tools)
setup_development_tools() {
    log_info "Setting up development tools..."
    
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
    
    sudo pacman -S --needed --noconfirm \
        firefox \
        qutebrowser \
        yt-dlp \
        mpv
    
    log_success "Browsers installed"
}

# Install applications - productivity (applications/productivity)
install_productivity_apps() {
    log_info "Installing productivity applications..."
    
    # Install from official repos
    sudo pacman -S --needed --noconfirm \
        gnucash \
        krdc
    
    # Install from AUR
    yay -S --needed --noconfirm \
        nextcloud-client \
        obsidian \
        todoist-appimage \
        zoom \
        timer-bin
    
    log_success "Productivity applications installed"
}

# Install applications - media (applications/media)
install_media_apps() {
    log_info "Installing media applications..."
    
    # Remove conflicting packages
    sudo pacman -Rns --noconfirm totem totem-plugins 2>/dev/null || true
    
    # Install media tools
    sudo pacman -S --needed --noconfirm vlc
    
    # Install music tools
    sudo pacman -S --needed --noconfirm \
        mpd \
        ncmpcpp \
        mpc \
        beets \
        python-requests \
        rmpc
    
    # Configure locale for music applications
    echo "LC_ALL=en_US.UTF-8" | sudo tee -a /etc/environment
    sudo locale-gen en_US.UTF-8
    
    # Disable system MPD service in favor of user service
    sudo systemctl stop mpd.service 2>/dev/null || true
    sudo systemctl disable mpd.service 2>/dev/null || true
    
    # Create MPD user service directory
    mkdir -p ~/.config/systemd/user
    
    # Create MPD user service file
    cat > ~/.config/systemd/user/mpd.service << 'EOF'
[Unit]
Description=Music Player Daemon
After=network.target sound.target

[Service]
Type=simple
ExecStart=/usr/bin/mpd --no-daemon
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
    
    # User MPD service will be enabled at end of installation
    
    log_success "Media applications installed"
}

# Install applications - steam (applications/steam)
install_steam() {
    log_info "Installing Steam..."
    
    # Enable multilib repository
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
        sudo pacman -Sy --noconfirm
    fi
    
    # Install Steam and dependencies
    sudo pacman -S --needed --noconfirm \
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
    sudo pacman -S --needed --noconfirm \
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
    
    # Install lbdb from AUR
    yay -S --needed --noconfirm lbdb
    
    log_success "Terminal mail client installed"
}

# Setup flatpak (applications/flatpak)
setup_flatpak() {
    log_info "Setting up Flatpak..."
    
    sudo pacman -S --needed --noconfirm flatpak
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    
    log_success "Flatpak setup completed"
}

# Install desktop - Hyprland (desktop/hyprland)
install_hyprland() {
    log_info "Installing Hyprland desktop environment..."
    
    # Install core Hyprland packages
    sudo pacman -S --needed --noconfirm \
        sddm \
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
        swww \
        gnome-keyring \
        libsecret \
        networkmanager \
        network-manager-applet \
        brightnessctl \
        pavucontrol
    
    # Services will be enabled at the end of installation
    
    # Install Hyprland ecosystem
    sudo pacman -S --needed --noconfirm \
        waybar \
        hyprpaper \
        hyprpicker \
        hypridle \
        hyprlock \
        hyprcursor \
        hyprpolkitagent
    
    # Install theme dependencies
    sudo pacman -S --needed --noconfirm \
        ttf-fantasque-sans-mono \
        ttf-fantasque-nerd
    
    log_success "Hyprland desktop environment installed"
}

# Install desktop - fonts (desktop/fonts)
install_fonts() {
    log_info "Installing fonts..."
    
    sudo pacman -S --needed --noconfirm \
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
    
    sudo pacman -S --needed --noconfirm \
        alacritty \
        kitty
    
    log_success "Terminals installed"
}

# Install desktop - file manager (desktop/filemanager)
install_file_manager() {
    log_info "Installing file managers..."
    
    # Install Ranger and dependencies
    sudo pacman -S --needed --noconfirm \
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
    sudo pacman -S --needed --noconfirm \
        thunar \
        thunar-volman \
        gvfs \
        gvfs-smb \
        smbclient \
        cifs-utils \
        libsecret
    
    log_success "File managers installed"
}

# Install work tools (work)
install_work_tools() {
    log_info "Installing work tools..."
    
    yay -S --needed --noconfirm icaclient
    
    log_success "Work tools installed"
}

# Enable system services
enable_services() {
    log_info "Enabling system services..."
    
    # Enable NetworkManager (needed for network connectivity)
    sudo systemctl enable --now NetworkManager
    
    # Enable bluetooth service
    sudo systemctl enable --now bluetooth
    
    # Enable user MPD service
    systemctl --user daemon-reload
    systemctl --user enable --now mpd.service 2>/dev/null || true
    
    # Enable Syncthing user service
    systemctl --user enable --now syncthing@$USER.service 2>/dev/null || true
    
    # Enable SDDM last (this will start the GUI login screen)
    sudo systemctl enable sddm
    
    log_success "System services enabled"
    log_warning "SDDM display manager will start on next boot. Reboot to enter GUI environment."
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
    
    # Run initial setup first
    initial_setup
    
    # Execute roles in the same order as core.yml
    
    # system/base
    install_base_packages
    configure_user_shell
    configure_system_services
    
    # system/security  
    configure_pass
    
    # workstation
    install_aur_helper
    setup_dotfiles
    
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
    setup_flatpak
    
    # desktop
    install_hyprland
    install_fonts
    install_terminals
    install_file_manager
    
    # work
    install_work_tools
    
    # Enable all services at the end
    enable_services
    
    log_success "Workstation Builder installation completed successfully!"
    log_info "Please reboot your system to ensure all changes take effect."
}

# Run main function
main "$@"
