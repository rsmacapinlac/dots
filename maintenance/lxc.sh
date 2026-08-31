#!/bin/bash
#
# LXC Maintenance Script - Keep Debian LXC packages and dotfiles up to date
#
# Run regularly to update: system packages, dotfiles, npm globals,
# mise tools, neovim plugins, and lazygit.
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

update_system_packages() {
    log_info "Updating system packages..."
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get autoremove -y
    log_success "System packages updated"
}

update_dotfiles() {
    log_info "Updating dotfiles via rcup..."
    if command -v rcup &>/dev/null; then
        rcup -v
        log_success "Dotfiles updated"
    else
        log_warning "rcup not found, skipping"
    fi
}

configure_npm_user_prefix() {
    if ! command -v npm &>/dev/null; then
        log_warning "npm not found, skipping npm user prefix setup"
        return 0
    fi

    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global"
    export PATH="$HOME/.npm-global/bin:$PATH"
}

update_npm_packages() {
    log_info "Updating npm global packages..."
    if command -v npm &>/dev/null; then
        configure_npm_user_prefix
        npm update -g
        log_success "npm global packages updated"
    else
        log_warning "npm not found, skipping"
    fi
}

update_nvim_plugins() {
    log_info "Updating Neovim plugins..."
    if command -v nvim &>/dev/null; then
        nvim --headless -c "Lazy! sync" -c "qa" 2>/dev/null \
            || log_warning "Failed to update Nvim plugins"
    else
        log_warning "nvim not found, skipping"
    fi
}

update_mise_tools() {
    log_info "Updating mise-managed tools..."

    if ! command -v mise &>/dev/null; then
        curl -fsSL https://mise.run | sh || {
            log_warning "mise install failed"
            return 0
        }
    fi

    export PATH="$HOME/.local/bin:$PATH"
    if [[ -x "$HOME/workspace/dots/setup/install-mise-tools" ]]; then
        "$HOME/workspace/dots/setup/install-mise-tools"
    else
        log_warning "dots checkout not found, skipping mise wrapper refresh"
        return 0
    fi
    MISE_MINIMUM_RELEASE_AGE=0 mise up
    log_success "mise-managed tools updated"
}

update_lazygit() {
    log_info "Checking for lazygit updates..."

    if ! command -v lazygit &>/dev/null; then
        log_warning "lazygit not installed, skipping"
        return 0
    fi

    local current_version latest_version
    current_version=$(lazygit --version | grep -oP '(?<=version=)[^,]+' | head -1)
    latest_version=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
        | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')

    if [[ "$current_version" == "$latest_version" ]]; then
        log_info "lazygit is up to date (${current_version})"
        return 0
    fi

    log_info "Updating lazygit ${current_version} → ${latest_version}..."
    curl -Lo /tmp/lazygit.tar.gz \
        "https://github.com/jesseduffield/lazygit/releases/download/v${latest_version}/lazygit_${latest_version}_Linux_x86_64.tar.gz"
    tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
    sudo install /tmp/lazygit /usr/local/bin/lazygit
    rm -f /tmp/lazygit /tmp/lazygit.tar.gz

    log_success "lazygit updated to ${latest_version}"
}

main() {
    log_info "Starting LXC maintenance..."

    update_system_packages
    update_dotfiles
    update_npm_packages
    update_mise_tools
    update_nvim_plugins
    update_lazygit

    log_success "Maintenance complete!"
}

main "$@"
