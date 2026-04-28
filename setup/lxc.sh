#!/bin/bash
#
# LXC Setup Script - RSM's Debian LXC Configuration
#
# Designed for Debian 12 (bookworm) LXC containers on Proxmox VE.
# SSH-only, headless. Primary use: Claude Code AI agent work.
#
# This script always installs the latest available versions:
# - Debian packages: automatically latest via apt
# - GitHub releases: fetched via GitHub API (latest release)
# - Git repositories: shallow clones from main branch (latest commit)
# - npm packages: installed globally with latest version
#
# Safe to rerun - all steps check for existing installations.
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Fetch latest GitHub release download URL for a given pattern
# Usage: get_latest_github_release "owner/repo" "filename_pattern"
get_latest_github_release() {
    local repo=$1
    local pattern=${2:-""}

    local url
    url=$(curl -s "https://api.github.com/repos/$repo/releases?per_page=1" \
        | grep -o "https://github.com/$repo/releases/download/[^\"]*" | head -1)

    if [[ -z "$url" ]]; then
        log_error "Failed to fetch latest release for $repo"
        return 1
    fi

    if [[ -n "$pattern" ]]; then
        url=$(curl -s "https://api.github.com/repos/$repo/releases?per_page=5" \
            | grep -o "https://github.com/$repo/releases/download/[^\"]*$pattern[^\"]*" | head -1)

        if [[ -z "$url" ]]; then
            log_warning "No release matching pattern '$pattern' found, using latest"
            url=$(curl -s "https://api.github.com/repos/$repo/releases?per_page=1" \
                | grep -o "https://github.com/$repo/releases/download/[^\"]*" | head -1)
        fi
    fi

    echo "$url"
}

check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Run as a regular user with sudo privileges."
        exit 1
    fi
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=${ID:-}
        log_info "Detected distribution: ${PRETTY_NAME:-$DISTRO}"
    else
        log_error "Cannot detect Linux distribution"
        exit 1
    fi
}

# Update apt and bootstrap packages needed for everything that follows
initial_setup() {
    log_info "Running initial setup..."

    sudo apt-get update
    sudo apt-get install -y \
        openssh-server \
        git \
        curl \
        gnupg \
        ca-certificates

    log_info "Checking SSH keys..."
    if [[ -d ~/.ssh && -f ~/.ssh/id_rsa ]]; then
        log_info "SSH keys already exist, skipping"
    else
        local ssh_source
        if [[ -d "./ssh" ]]; then
            ssh_source="./ssh"
        else
            read -rp "SSH folder not found in current directory. Enter path to SSH folder: " ssh_source
            if [[ ! -d "$ssh_source" ]]; then
                log_error "SSH folder not found at $ssh_source"
                exit 1
            fi
        fi
        mkdir -p ~/.ssh
        cp "$ssh_source"/* ~/.ssh/
        chmod 600 ~/.ssh/id_rsa
        log_success "SSH keys installed"
    fi

    # Clone password store - assumes GPG keys are configured by user before running
    mkdir -p ~/workspace
    if [[ ! -d ~/.password-store ]]; then
        # Only start SSH agent when we actually need it for the clone
        eval "$(ssh-agent -s)"
        ssh-add ~/.ssh/id_rsa
        if git clone git@github.com:rsmacapinlac/cautious-dollop.git ~/.password-store 2>/dev/null; then
            log_success "Password store cloned"
        else
            log_warning "Could not clone password store - configure GPG keys first, then rerun"
        fi
    else
        log_info "Password store already exists, skipping"
    fi

    log_success "Initial setup completed"
}

install_base_packages() {
    log_info "Installing base system packages..."

    sudo apt-get install -y \
        htop \
        zsh \
        wget \
        unzip \
        build-essential \
        pkg-config \
        pinentry-curses \
        locales

    # Ensure en_US.UTF-8 locale is available
    if ! locale -a 2>/dev/null | grep -q "en_US.utf8"; then
        sudo locale-gen en_US.UTF-8
    fi

    log_success "Base system packages installed"
}

# Install Node.js via NodeSource — avoids the nodejs/npm apt conflict in Debian 12
install_nodejs() {
    if command -v node &>/dev/null; then
        log_info "Node.js already installed ($(node --version)), skipping"
        return 0
    fi

    log_info "Installing Node.js 20 LTS via NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs

    log_success "Node.js $(node --version) installed"
}

# Configure user-level npm prefix to avoid sudo for global installs
configure_npm() {
    log_info "Configuring npm..."

    if [[ ! -d "$HOME/.npm-global" ]]; then
        mkdir -p "$HOME/.npm-global"
        npm config set prefix "$HOME/.npm-global"
        log_success "npm prefix set to ~/.npm-global"
    else
        log_info "npm prefix already configured, skipping"
    fi

    # Add ~/.npm-global/bin to PATH for zsh login shells (not managed by dotfiles)
    if ! grep -q "npm-global/bin" "$HOME/.zprofile" 2>/dev/null; then
        echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.zprofile"
        log_info "Added ~/.npm-global/bin to PATH in ~/.zprofile"
    fi

    # Apply in current session so npm installs later in this script work
    export PATH="$HOME/.npm-global/bin:$PATH"
}

configure_user_shell() {
    log_info "Configuring user shell..."

    sudo chsh -s /bin/zsh "$USER"

    if [[ -d ~/.oh-my-zsh ]]; then
        log_info "oh-my-zsh already installed, skipping"
    else
        log_info "Installing oh-my-zsh..."
        curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /tmp/omz-install.sh
        sh /tmp/omz-install.sh --unattended
        rm -f /tmp/omz-install.sh
        log_success "oh-my-zsh installed"
    fi

    log_success "User shell configured"
}

configure_security() {
    log_info "Configuring security tools..."

    sudo apt-get install -y \
        pass \
        pass-otp \
        wireguard-tools \
        openresolv

    # Bitwarden CLI via npm (consistent with workstation setup)
    if ! command -v bw &>/dev/null; then
        npm install -g @bitwarden/cli
        log_success "Bitwarden CLI installed"
    else
        log_info "Bitwarden CLI already installed, skipping"
    fi

    log_success "Security tools configured"
}

setup_dotfiles() {
    log_info "Setting up dotfiles..."

    if ! command -v rcup &>/dev/null; then
        sudo wget -q https://apt.tabfugni.cc/thoughtbot.gpg.key \
            -O /etc/apt/trusted.gpg.d/thoughtbot.gpg
        echo "deb https://apt.tabfugni.cc/debian/ stable main" \
            | sudo tee /etc/apt/sources.list.d/thoughtbot.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y rcm
        log_success "rcm installed"
    else
        log_info "rcm already installed, skipping"
    fi

    mkdir -p "$HOME/workspace"
    if [[ ! -d "$HOME/workspace/dots" ]]; then
        git clone git@github.com:rsmacapinlac/dots.git "$HOME/workspace/dots" || \
            git clone https://github.com/rsmacapinlac/dots.git "$HOME/workspace/dots"
    else
        log_info "Dots repository already exists, skipping clone"
    fi

    env RCRC="$HOME/workspace/dots/rcrc" rcup -f

    log_success "Dotfiles configured"
}

install_development_packages() {
    log_info "Installing development packages..."

    sudo apt-get install -y \
        ripgrep \
        fd-find \
        make \
        ruby-full \
        ruby-dev \
        python3-pip \
        python3-dev \
        libtool-bin

    # Debian installs fd as fdfind; create fd symlink for neovim plugins and muscle memory
    if ! command -v fd &>/dev/null; then
        sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd
        log_info "Created fd symlink → fdfind"
    fi

    # pynvim for Python-based neovim plugins
    # Use pip directly — apt's python3-pynvim pulls in old neovim 0.7.2 as a dependency
    # --break-system-packages required on Debian 12+ (PEP 668)
    pip3 install --user pynvim --break-system-packages --quiet

    log_success "Development packages installed"
}

install_fastfetch() {
    if command -v fastfetch &>/dev/null; then
        log_info "fastfetch already installed, skipping"
        return 0
    fi

    log_info "Installing fastfetch build dependencies..."
    sudo apt-get install -y cmake ninja-build

    log_info "Cloning and building fastfetch from source..."
    rm -rf /tmp/fastfetch
    git clone --depth 1 https://github.com/fastfetch-cli/fastfetch /tmp/fastfetch
    cmake -S /tmp/fastfetch -B /tmp/fastfetch/build -DCMAKE_BUILD_TYPE=Release
    cmake --build /tmp/fastfetch/build -j"$(nproc)"
    sudo cmake --install /tmp/fastfetch/build
    rm -rf /tmp/fastfetch

    log_success "fastfetch installed"
}

install_lazygit() {
    if command -v lazygit &>/dev/null; then
        log_info "lazygit already installed, skipping"
        return 0
    fi

    log_info "Installing lazygit..."

    local version
    version=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
        | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')

    curl -Lo /tmp/lazygit.tar.gz \
        "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_x86_64.tar.gz"
    tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
    sudo install /tmp/lazygit /usr/local/bin/lazygit
    rm -f /tmp/lazygit /tmp/lazygit.tar.gz

    log_success "lazygit ${version} installed"
}

# Builds from the latest neovim source. Takes several minutes on first run.
install_neovim() {
    if [[ -f /usr/local/bin/nvim ]]; then
        log_info "Neovim already installed from source ($(/usr/local/bin/nvim --version | head -1)), skipping"
        return 0
    fi

    # apt's python3-pynvim pulls in neovim 0.7.2 as a dependency; remove it before building
    if dpkg -l neovim &>/dev/null 2>&1; then
        log_info "Removing apt-installed neovim before source build..."
        sudo apt-get remove -y neovim
    fi

    log_info "Installing Neovim build dependencies..."
    sudo apt-get install -y \
        ninja-build \
        gettext \
        cmake \
        unzip \
        curl \
        lua5.1

    log_info "Cloning and building Neovim from source (this takes several minutes)..."
    rm -rf /tmp/neovim
    git clone --depth 1 https://github.com/neovim/neovim /tmp/neovim
    # Use neovim's Makefile rather than cmake directly — it builds bundled luv/luajit
    # automatically, avoiding system library version mismatches on Debian 12
    make -C /tmp/neovim CMAKE_BUILD_TYPE=RelWithDebInfo -j"$(nproc)"
    sudo make -C /tmp/neovim install
    rm -rf /tmp/neovim

    log_success "Neovim built and installed from source"
}

install_gh() {
    if command -v gh &>/dev/null; then
        log_info "GitHub CLI already installed, skipping"
        return 0
    fi

    log_info "Installing GitHub CLI..."

    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y gh

    log_success "GitHub CLI installed"
}

install_claude_code() {
    if command -v claude &>/dev/null; then
        log_info "Claude Code already installed ($(claude --version 2>/dev/null || echo 'unknown version')), skipping"
        return 0
    fi

    log_info "Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code

    log_success "Claude Code installed"
}

setup_development_tools() {
    log_info "Setting up development tools..."

    sudo apt-get install -y tmux

    if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        git clone --depth 1 https://github.com/tmux-plugins/tpm.git "$HOME/.tmux/plugins/tpm"
        log_info "TPM installed"
    else
        log_info "TPM already installed, skipping"
    fi

    if [[ ! -d "$HOME/.rvm" ]]; then
        log_info "Installing RVM..."
        curl -sSL https://get.rvm.io | bash
        log_success "RVM installed"
    else
        log_info "RVM already installed, skipping"
    fi

    log_success "Development tools configured"
}

enable_services() {
    log_info "Enabling system services..."

    sudo systemctl enable ssh
    sudo systemctl start ssh

    log_success "Services enabled"
}

main() {
    log_info "Starting LXC setup..."

    check_not_root
    detect_distro

    if [[ "$DISTRO" != "debian" ]]; then
        log_error "This script only supports Debian Linux"
        exit 1
    fi

    initial_setup
    install_base_packages
    install_nodejs
    configure_npm
    configure_user_shell
    configure_security
    setup_dotfiles
    install_development_packages
    install_fastfetch
    install_lazygit
    install_neovim
    install_gh
    install_claude_code
    setup_development_tools
    enable_services

    log_success "LXC setup completed!"
    log_info "Start a new shell session for all changes to take effect."
    log_warning "NOTE: Configure GPG keys before using pass or cloning the password store."
}

main "$@"
