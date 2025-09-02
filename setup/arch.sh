#!/bin/bash
#
# Workstation Builder - RSM's Unified Installation Script
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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


# Initial setup function for SSH and GPG
initial_setup() {
    log_info "Update system and install minimal packages required for initial setup..."

    # Update system first
    sudo pacman -Sy --noconfirm

    # Install minimal packages needed for initial setup
    sudo pacman -Sy --noconfirm openssh git

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
    
    
    log_success "Initial setup completed"
}

# Install base system packages (system/base/packages)
install_base_packages() {
    log_info "Installing base system packages..."
    
    # Remove conflicting polkit packages
    yay -Rns --noconfirm ksshaskpass polkit-gnome 2>/dev/null || true
    
    # Install base system packages
    yay -S --needed --noconfirm \
        polkit-kde-agent \
        curl \
        base-devel \
        zsh \
        nodejs \
        npm \
        fastfetch \
        autorandr \
        syncthing \
        seahorse \
        cups \
        cups-pdf \
        system-config-printer \
        avahi \
        nss-mdns
    
    # Configure SSH askpass to use Seahorse GUI
    if [[ ! -L /usr/lib/ssh/ssh-askpass ]]; then
        sudo ln -sf /usr/lib/seahorse/ssh-askpass /usr/lib/ssh/ssh-askpass
        log_success "SSH askpass configured to use Seahorse"
    fi
    
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
    
    # Download and install oh-my-zsh
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /tmp/install.sh
    sh /tmp/install.sh --unattended
    
    log_success "User shell configured"
}

# Configure system services (system/base/services)
configure_system_services() {
    log_info "Configuring system services..."
    
    # Install system services packages
    yay -S --needed --noconfirm \
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
    
    # Setup password repository 
    mkdir -p ~/workspace && cd ~/workspace
    if [[ ! -d ~/.password-store ]]; then
        git clone git@github.com:rsmacapinlac/cautious-dollop.git ~/.password-store
        log_success "Password store repository cloned"
    else
        log_info "Password store already exists, skipping clone"
    fi

    # Install pass password manager and extensions
    yay -S --needed --noconfirm \
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
    log_warning "NOTE: Pass requires manual GPG key setup - run 'gpg --full-gen-key' then 'pass init <email>'"
}

# Configure Timeshift snapshots (system/snapshots)
configure_timeshift() {
    log_info "Configuring Timeshift integration..."
    
    # Install timeshift and related packages
    yay -S --needed --noconfirm \
        timeshift \
        timeshift-gtk \
        grub-btrfs \
        grub-btrfsd \
        inotify-tools \
        timeshift-autosnap 
    
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
    # Remove conflicting rcm-git package if present
    yay -Rns --noconfirm rcm-git 2>/dev/null || true
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
    
    yay -S --needed --noconfirm \
        ruby \
        ruby-erb \
        ripgrep \
        fd \
        xclip \
        python-pynvim \
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
    yay -S --needed --noconfirm \
        neovim \
    
    # Install editors from AUR
    yay -S --needed --noconfirm \
        cursor-bin \
        claude-code

    log_success "Development editors installed"
}

# Setup development tools (development/tools)
setup_development_tools() {
    log_info "Setting up development tools..."
    
    yay -S --needed --noconfirm \
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
    
    yay -S --needed --noconfirm \
        firefox \
        qutebrowser \
        yt-dlp \
        mpv
    
    log_success "Browsers installed"
}

# Install applications - productivity (applications/productivity)
install_productivity_apps() {
    log_info "Installing productivity applications..."
    
    # Install from AUR
    yay -S --needed --noconfirm \
        gnucash \
        krdc \
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
    yay -Rns --noconfirm totem totem-plugins 2>/dev/null || true
    
    sudo pacman -S --needed --noconfirm \
        vlc \
        vlc-plugins-all \
        mpd \
        ncmpcpp \
        mpc \
        beets \
        python-requests \
        rmpc
    
    # Configure locale for music applications
    echo "LC_ALL=en_US.UTF-8" | sudo tee -a /etc/environment
    sudo locale-gen en_US.UTF-8
    
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
        yay -Sy --noconfirm
    fi
    
    # Install Steam and dependencies
    yay -S --needed --noconfirm \
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
    yay -S --needed --noconfirm \
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
        p7zip \
        lbdb
    
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
    yay -S --needed --noconfirm \
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
        pavucontrol \
        waybar \
        hyprpaper \
        hyprpicker \
        hypridle \
        hyprlock \
        hyprcursor \
        hyprpolkitagent \
        ttf-fantasque-sans-mono \
        ttf-fantasque-nerd
    
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
    yay -S --needed --noconfirm greetd
    
    # Create greetd configuration directory
    sudo mkdir -p /etc/greetd
    
    # Configure greetd to boot directly into Hyprland
    sudo tee /etc/greetd/config.toml > /dev/null << EOF
[terminal]
vt = 1

[default_session]
command = "uwsm start hyprland"
user = "greeter"

[initial_session]
command = "uwsm start hyprland"
user = "$USER"
EOF
    
    # Enable greetd service
    sudo systemctl enable greetd
    
    log_success "greetd installed and configured"
}

# Install desktop - fonts (desktop/fonts)
install_fonts() {
    log_info "Installing fonts..."
    
    yay -S --needed --noconfirm \
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
    
    yay -S --needed --noconfirm \
        alacritty \
        kitty
    
    log_success "Terminals installed"
}

# Install desktop - file manager (desktop/filemanager)
install_file_manager() {
    log_info "Installing file managers..."
    
    # Install Ranger and dependencies
    yay -S --needed --noconfirm \
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
    yay -S --needed --noconfirm \
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

# Install VirtualBox (virtualization)
install_virtualization() {
    log_info "Installing VirtualBox virtualization..."
    
    # Check if VirtualBox is already installed with DKMS modules
    if pacman -Q virtualbox-host-dkms &>/dev/null; then
        log_info "Switching from DKMS to arch modules (better for standard kernel)..."
        # Remove VirtualBox and DKMS modules completely
        sudo pacman -Rs --noconfirm virtualbox virtualbox-host-dkms 2>/dev/null || true
    fi
    
    # Install VirtualBox packages with arch modules
    yay -S --needed --noconfirm \
        virtualbox \
        virtualbox-host-modules-arch \
        virtualbox-guest-iso
    
    log_success "VirtualBox installed"
}

# Configure VirtualBox (virtualization) 
configure_virtualization() {
    log_info "Configuring VirtualBox..."
    
    # Add user to vboxusers group (for USB device access)
    sudo usermod -a -G vboxusers "$USER"
    
    # Load VirtualBox kernel modules manually (they will auto-load on next boot)
    log_info "Loading VirtualBox kernel modules..."
    sudo modprobe vboxdrv || true
    sudo modprobe vboxnetadp || true
    sudo modprobe vboxnetflt || true
    sudo modprobe vboxpci || true
    
    log_success "VirtualBox configured"
    log_info "Modules will automatically load on boot via systemd-modules-load.service"
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
    
    # Enable gnome-keyring 
    systemctl --user enable gnome-keyring-daemon 2>/dev/null || true

    # Enable Syncthing user service
    systemctl --user enable syncthing.service 2>/dev/null || true
    
    # Enable hypridle service (screen lock and idle management)
    systemctl --user enable --now hypridle.service 2>/dev/null || true
    
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
    
    # Run initial setup first
    initial_setup
    
    # maybe standardize on yay?
    install_aur_helper
    
    # system/base
    install_base_packages
    configure_user_shell
    configure_system_services
    
    # workstation
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
    
    # work
    install_work_tools
    
    # virtualization
    install_virtualization
    configure_virtualization
    
    # Enable all services at the end
    enable_services
    
    log_success "Workstation Builder installation completed successfully!"
    log_info "Please reboot your system to ensure all changes take effect."
}

# Run main function
main "$@"
