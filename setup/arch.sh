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

# Wrapper for yay to prevent hanging on interactive AUR prompts
yay_install() {
    yay -S --needed --noconfirm --answerdiff None --answerclean None --removemake "$@"
}

# Fetch latest GitHub release download URL for a given pattern
# Usage: get_latest_github_release "owner/repo" "filename_pattern"
# Example: get_latest_github_release "bambulab/BambuStudio" "ubuntu-22.04.*AppImage"
get_latest_github_release() {
    local repo=$1
    local pattern=${2:-""}

    local url=$(curl -s "https://api.github.com/repos/$repo/releases?per_page=1" \
        | grep -o "https://github.com/$repo/releases/download/[^\"]*" | head -1)

    if [[ -z "$url" ]]; then
        log_error "Failed to fetch latest release for $repo"
        return 1
    fi

    # If pattern provided, filter for matching filename
    if [[ -n "$pattern" ]]; then
        url=$(curl -s "https://api.github.com/repos/$repo/releases?per_page=5" \
            | grep -o "https://github.com/$repo/releases/download/[^\"]*$pattern[^\"]*" | head -1)

        if [[ -z "$url" ]]; then
            log_warning "No release matching pattern '$pattern' found, using latest release"
            url=$(curl -s "https://api.github.com/repos/$repo/releases?per_page=1" \
                | grep -o "https://github.com/$repo/releases/download/[^\"]*" | head -1)
        fi
    fi

    echo "$url"
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

    # Update system first
    sudo pacman -Sy --noconfirm

    # Update mirrors early to ensure fast package downloads
    update_package_mirrors

    # Install minimal packages needed for initial setup
    sudo pacman -S --needed --noconfirm openssh git

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
    yay_install \
        htop \
        polkit-kde-agent \
        curl \
        base-devel \
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
        pinentry-qt
    
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
    
    # Setup password repository 
    mkdir -p ~/workspace && cd ~/workspace
    if [[ ! -d ~/.password-store ]]; then
        git clone git@github.com:rsmacapinlac/cautious-dollop.git ~/.password-store
        log_success "Password store repository cloned"
    else
        log_info "Password store already exists, skipping clone"
    fi

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
    log_warning "NOTE: Pass requires manual GPG key setup - run 'gpg --full-gen-key' then 'pass init <email>'"
}

# Configure Timeshift snapshots (system/snapshots)
configure_timeshift() {
    log_info "Configuring Timeshift integration..."
    
    # Install timeshift and related packages
    yay_install \
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
    yay_install rcm
    
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
    
    yay_install \
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
    
    yay_install \
        firefox \
        qutebrowser \
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
        mpd \
        ncmpcpp \
        mpc \
        python-requests \
        beets \
        python-pyacoustid \
        python-discogs-client \
        rmpc \
        handbrake
    
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

# Install 3D printing tools (3d-printing)
install_3d_printing_tools() {
    log_info "Installing 3D printing software (AppImage)..."

    # Create applications directory
    mkdir -p "$HOME/.local/share/applications"
    mkdir -p "$HOME/.local/bin"

    # Install FUSE2 and library dependencies required for AppImage support
    yay_install \
        libfuse2 \
        libtiff5

    # Fetch latest Bambu Studio AppImage using helper function
    log_info "Fetching latest Bambu Studio release..."
    local appimage_url=$(get_latest_github_release "bambulab/BambuStudio" "ubuntu-22.04.*AppImage")

    if [[ -z "$appimage_url" ]]; then
        log_warning "Failed to fetch latest Bambu Studio release URL"
        return 1
    fi

    local appimage_path="$HOME/.local/bin/bambustudio"

    log_info "Downloading Bambu Studio AppImage from: $appimage_url"
    if curl -sSL -o "$appimage_path" "$appimage_url"; then
        chmod +x "$appimage_path"
        log_success "Bambu Studio AppImage installed to $appimage_path"
    else
        log_warning "Failed to download Bambu Studio AppImage"
        return 1
    fi

    # Create desktop entry for easy access (use full path, not ~)
    cat > "$HOME/.local/share/applications/bambustudio.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Bambu Studio
Exec=$HOME/.local/bin/bambustudio %U
Icon=application-x-executable
Categories=Utility;3DPrinting;
Comment=3D printing software for Bambu Lab and other printers
Terminal=false
StartupNotify=true
EOF

    log_success "3D printing tools installed"
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
    sudo npm install -g agent-browser
    agent-browser install

    # Install pi-coding-agent: minimalist AI coding agent
    # https://github.com/badlogic/pi-mono
    yay_install pi-coding-agent

    log_success "AI tools installed"
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

# Install work tools (work)
install_work_tools() {
    log_info "Installing work tools..."
    
    yay_install icaclient
    
    log_success "Work tools installed"
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
        swtpm-tools \
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
    yay -Syu --noconfirm --answerdiff None --answerclean None --removemake

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

    # 3d-printing
    install_3d_printing_tools

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

    # work
    install_work_tools

    # raspberry pi
    install_rpi_tools
    
    # virtualization
    verify_virtualization_support
    install_virtualization
    configure_virtualization
    
    # Enable all services at the end
    enable_services
    
    log_success "Workstation Builder installation completed successfully!"
    log_info "Please reboot your system to ensure all changes take effect."
}

# Run main function
main "$@"
