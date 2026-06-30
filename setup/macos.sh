#!/bin/bash
#
# macOS Setup Script - RSM's terminal-first macOS workstation configuration
#
# Designed for a fresh or lightly configured macOS host.
# Installs Homebrew packages, configures npm user globals, clones/applies
# dotfiles via rcm, and installs AI/dev tools used by this repo.
#
# Safe to rerun: package installs and clones check for existing state.
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PI_SUBAGENTS_PACKAGE="npm:@tintinweb/pi-subagents"

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Run as your normal macOS user."
        exit 1
    fi
}

check_macos() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        log_error "This script only supports macOS"
        exit 1
    fi
    log_info "Detected macOS $(sw_vers -productVersion) on $(uname -m)"
}

ensure_xcode_clt() {
    if xcode-select -p &>/dev/null; then
        log_info "Xcode Command Line Tools already installed"
        return 0
    fi

    log_warning "Xcode Command Line Tools are required. Launching installer..."
    xcode-select --install || true
    log_error "Re-run this script after Xcode Command Line Tools finish installing."
    exit 1
}

install_homebrew() {
    if command -v brew &>/dev/null; then
        log_info "Homebrew already installed ($(brew --version | head -1))"
    else
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    local brew_bin
    if [[ -x /opt/homebrew/bin/brew ]]; then
        brew_bin=/opt/homebrew/bin/brew
    elif [[ -x /usr/local/bin/brew ]]; then
        brew_bin=/usr/local/bin/brew
    else
        brew_bin=$(command -v brew)
    fi

    eval "$("$brew_bin" shellenv)"

    mkdir -p "$HOME/.zprofile.d"
    if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
        {
            echo ''
            echo '# Homebrew'
            echo "eval \"\$(\"$brew_bin\" shellenv)\""
        } >> "$HOME/.zprofile"
        log_info "Added Homebrew shellenv to ~/.zprofile"
    fi

    brew update
    log_success "Homebrew ready"
}

brew_install_formulae() {
    local formula
    for formula in "$@"; do
        if brew list --formula "$formula" &>/dev/null; then
            log_info "$formula already installed"
        else
            log_info "Installing $formula..."
            if brew install "$formula"; then
                log_success "$formula installed"
            else
                log_warning "Failed to install formula: $formula"
            fi
        fi
    done
}

brew_install_casks() {
    local cask
    for cask in "$@"; do
        if brew list --cask "$cask" &>/dev/null; then
            log_info "$cask already installed"
        else
            log_info "Installing cask $cask..."
            if brew install --cask "$cask"; then
                log_success "$cask installed"
            else
                log_warning "Failed to install cask: $cask"
            fi
        fi
    done
}

get_latest_github_release_asset() {
    local repo=$1
    local pattern=$2

    curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=5" \
        | grep -om 1 "https://github.com/$repo/releases/download/[^\"]*$pattern[^\"]*" \
        || true
}

install_base_packages() {
    log_info "Installing base and terminal packages..."
    brew_install_formulae \
        git \
        curl \
        wget \
        rcm \
        zsh \
        htop \
        fastfetch \
        jq \
        gnupg \
        pinentry-mac \
        pass \
        pass-otp \
        bitwarden-cli \
        wireguard-tools \
        rsync \
        node
    log_success "Base packages installed"
}

configure_npm() {
    log_info "Configuring npm user prefix..."

    if ! command -v npm &>/dev/null; then
        log_warning "npm not found, skipping npm configuration"
        return 0
    fi

    mkdir -p "$HOME/.npm-global"
    if [[ "$(npm config get prefix)" != "$HOME/.npm-global" ]]; then
        npm config set prefix "$HOME/.npm-global"
    fi

    if ! grep -q 'npm-global/bin' "$HOME/.zprofile" 2>/dev/null; then
        echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.zprofile"
        log_info "Added ~/.npm-global/bin to PATH in ~/.zprofile"
    fi

    export PATH="$HOME/.npm-global/bin:$PATH"
    log_success "npm configured"
}

configure_user_shell() {
    log_info "Configuring zsh and oh-my-zsh..."

    local brew_zsh
    brew_zsh="$(brew --prefix)/bin/zsh"
    if [[ -x "$brew_zsh" ]]; then
        if ! grep -qx "$brew_zsh" /etc/shells; then
            echo "$brew_zsh" | sudo tee -a /etc/shells > /dev/null
        fi
        if [[ "$SHELL" != "$brew_zsh" ]]; then
            sudo chsh -s "$brew_zsh" "$USER"
        fi
    fi

    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        log_info "oh-my-zsh already installed"
    else
        log_info "Installing oh-my-zsh..."
        curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /tmp/omz-install.sh
        sh /tmp/omz-install.sh --unattended
        rm -f /tmp/omz-install.sh
        log_success "oh-my-zsh installed"
    fi

    log_success "User shell configured"
}

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

setup_dotfiles() {
    log_info "Setting up dotfiles..."

    mkdir -p "$HOME/workspace"
    if [[ ! -d "$HOME/workspace/dots" ]]; then
        git clone git@github.com:rsmacapinlac/dots.git "$HOME/workspace/dots" || \
            git clone https://github.com/rsmacapinlac/dots.git "$HOME/workspace/dots"
    else
        log_info "Dots repository already exists"
    fi

    env RCRC="$HOME/workspace/dots/rcrc" rcup -f
    log_success "Dotfiles configured"
}

install_passff_host() {
    local host_dir="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
    local host_script="$host_dir/passff.py"
    local manifest="$host_dir/passff.json"

    if [[ -s "$manifest" && -x "$host_script" ]]; then
        log_info "PassFF native messaging host already installed"
        return 0
    fi

    log_info "Installing PassFF native messaging host..."

    local version
    version=$(curl -fsSL "https://api.github.com/repos/passff/passff-host/releases/latest" \
        | grep '"tag_name"' | sed 's/.*"\([^"]*\)".*/\1/')

    if [[ -z "$version" ]]; then
        log_warning "Could not determine passff-host version, skipping"
        return 0
    fi

    mkdir -p "$host_dir"
    curl -fsSL "https://github.com/passff/passff-host/releases/download/${version}/passff.py" \
        -o "$host_script"
    chmod +x "$host_script"

    cat > "$manifest" <<EOF
{
    "name": "passff",
    "description": "Host app enabling PassFF browser extension to use the pass password manager",
    "path": "${host_script}",
    "type": "stdio",
    "allowed_extensions": ["passff@invicem.pro"]
}
EOF

    log_success "PassFF native messaging host installed for Firefox"
}

configure_security() {
    log_info "Configuring security tools..."

    if [[ ! -d "$HOME/.password-store" ]]; then
        git clone git@github.com:rsmacapinlac/cautious-dollop.git "$HOME/.password-store"
        log_success "Password store repository cloned"
    else
        log_info "Password store already exists, skipping clone"
    fi

    install_passff_host

    log_success "Security configuration completed"
}

install_development_packages() {
    log_info "Installing development packages..."
    brew_install_formulae \
        neovim \
        tmux \
        ripgrep \
        fd \
        fzf \
        lazygit \
        go \
        ruby \
        python \
        cmake \
        ninja \
        pkg-config \
        make

    if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
        git clone --depth 1 https://github.com/tmux-plugins/tpm.git "$HOME/.tmux/plugins/tpm"
        log_info "TPM installed"
    fi

    if [[ ! -d "$HOME/.rvm" ]]; then
        log_info "Installing RVM..."
        curl -sSL https://get.rvm.io | bash
    else
        log_info "RVM already installed"
    fi

    if [[ -x "$(brew --prefix)/opt/fzf/install" && ! -f "$HOME/.fzf.zsh" ]]; then
        "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
    fi

    log_success "Development packages installed"
}

install_terminal_apps() {
    log_info "Installing terminal-first application stack..."
    brew_install_formulae \
        ranger \
        atool \
        highlight \
        mediainfo \
        ffmpeg \
        yt-dlp \
        mpv \
        neomutt \
        isync \
        msmtp \
        notmuch \
        urlscan \
        lynx \
        w3m \
        imagemagick \
        unzip \
        p7zip \
        lbdb \
        mpd \
        ncmpcpp \
        mpc \
        beets \
        cava
    log_success "Terminal applications installed"
}

install_rmpc() {
    if command -v rmpc &>/dev/null; then
        log_info "rmpc already installed, skipping"
        return 0
    fi

    log_info "Installing rmpc..."

    local arch
    case "$(uname -m)" in
        arm64)  arch="aarch64-apple-darwin" ;;
        x86_64) arch="x86_64-apple-darwin" ;;
        *)
            log_warning "Unsupported architecture $(uname -m), skipping rmpc install"
            return 0
            ;;
    esac

    local version url tmpdir
    version=$(curl -s "https://api.github.com/repos/mierak/rmpc/releases/latest" \
        | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
    url="https://github.com/mierak/rmpc/releases/download/v${version}/rmpc-v${version}-${arch}.tar.gz"

    tmpdir=$(mktemp -d)
    curl -fsSL "$url" -o "$tmpdir/rmpc.tar.gz"
    tar -xzf "$tmpdir/rmpc.tar.gz" -C "$tmpdir"
    install -m 0755 "$tmpdir/rmpc" "$(brew --prefix)/bin/rmpc"
    rm -rf "$tmpdir"

    log_success "rmpc ${version} installed"
}

configure_mpd_service() {
    log_info "Configuring MPD service..."

    mkdir -p "$HOME/.config/mpd" "$HOME/Music"

    if command -v brew &>/dev/null && brew list --formula mpd &>/dev/null; then
        mkdir -p "$(brew --prefix)/etc"
        ln -sfn "$HOME/.config/mpd/mpd.conf" "$(brew --prefix)/etc/mpd.conf"

        if brew services list | awk '$1 == "mpd" && $2 == "started" { found = 1 } END { exit !found }'; then
            log_info "MPD Homebrew service already started"
        elif brew services start mpd; then
            log_success "MPD Homebrew service started"
        else
            log_warning "Failed to start MPD Homebrew service"
        fi
    else
        log_warning "MPD is not installed; skipping service setup"
    fi
}

install_gui_apps() {
    log_info "Installing keyboard-friendly GUI/support apps..."
    brew_install_casks \
        font-noto-sans-cjk \
        kitty \
        alacritty \
        qutebrowser \
        firefox \
        bitwarden \
        obsidian \
        slack \
        telegram \
        todoist \
        vlc \
        zoom \
        cursor \
        nextcloud \
        raspberry-pi-imager
    log_success "GUI/support apps processed"
}

install_gogcli() {
    log_info "Installing gogcli Google Suite CLI..."
    brew_install_formulae gogcli
}

install_himalaya() {
    if command -v himalaya &>/dev/null; then
        log_info "himalaya already installed, skipping"
        return 0
    fi

    log_info "Installing himalaya..."

    local arch pattern url tmpdir binary
    case "$(uname -m)" in
        arm64)  arch="aarch64-darwin" ;;
        x86_64) arch="x86_64-darwin" ;;
        *)
            log_warning "Unsupported architecture $(uname -m), skipping himalaya install"
            return 0
            ;;
    esac

    pattern="himalaya.${arch}.tgz"
    url=$(get_latest_github_release_asset "pimalaya/himalaya" "$pattern")
    if [[ -z "$url" ]]; then
        log_warning "Could not find himalaya release asset for $pattern"
        return 0
    fi

    tmpdir=$(mktemp -d)
    if curl -fsSL "$url" -o "$tmpdir/himalaya.tgz" && tar -xzf "$tmpdir/himalaya.tgz" -C "$tmpdir"; then
        binary=$(find "$tmpdir" -type f -name himalaya | head -1)
        if [[ -n "$binary" ]] && install -m 0755 "$binary" "$(brew --prefix)/bin/himalaya"; then
            log_success "himalaya installed"
        else
            log_warning "himalaya binary not found in release archive"
        fi
    else
        log_warning "himalaya install failed"
    fi
    rm -rf "$tmpdir"
}

install_ai_tools() {
    log_info "Installing AI coding tools..."

    configure_npm
    install_himalaya
    install_gogcli

    if ! command -v agent-browser &>/dev/null; then
        npm install -g agent-browser
        log_success "agent-browser installed"
    else
        log_info "agent-browser already installed"
    fi

    if command -v agent-browser &>/dev/null; then
        agent-browser install || log_warning "agent-browser browser install failed"
    fi

    if ! command -v claude &>/dev/null; then
        npm install -g @anthropic-ai/claude-code
        log_success "Claude Code installed"
    else
        log_info "Claude Code already installed ($(claude --version 2>/dev/null || echo 'unknown version'))"
    fi

    if ! command -v pi &>/dev/null; then
        npm install -g @mariozechner/pi-coding-agent
        log_success "Pi coding agent installed"
    else
        log_info "Pi coding agent already installed ($(pi --version 2>/dev/null || echo 'unknown version'))"
    fi

    if command -v pi &>/dev/null; then
        if pi install "$PI_SUBAGENTS_PACKAGE"; then
            log_success "Pi subagents package installed"
        else
            log_warning "Pi subagents package install failed"
        fi
    fi

    log_success "AI tools installed"
}

main() {
    log_info "Starting macOS setup..."

    check_not_root
    check_macos
    ensure_xcode_clt
    install_homebrew
    install_base_packages
    configure_npm
    configure_user_shell
    configure_gnupg
    setup_dotfiles
    configure_security
    install_development_packages
    install_terminal_apps
    install_rmpc
    configure_mpd_service
    install_gui_apps
    install_ai_tools

    log_success "macOS setup completed!"
    log_info "Start a new shell session for PATH/shell changes to take effect."
}

main "$@"
