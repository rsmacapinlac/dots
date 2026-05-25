#!/bin/bash
#
# macOS Maintenance Script - Keep Homebrew, dotfiles, and dev tools current
#
# Updates Homebrew packages/casks, dotfiles via rcup, npm globals, Pi packages,
# oh-my-zsh, and Neovim plugins.
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

check_macos() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        log_error "This script only supports macOS"
        exit 1
    fi
}

load_homebrew() {
    if command -v brew &>/dev/null; then
        return 0
    fi

    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

update_homebrew_packages() {
    log_info "Updating Homebrew packages..."

    load_homebrew
    if ! command -v brew &>/dev/null; then
        log_warning "Homebrew not found, skipping"
        return 0
    fi

    brew update
    brew upgrade
    brew upgrade --cask --greedy || log_warning "Some cask upgrades failed"
    brew cleanup

    log_success "Homebrew packages updated"
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
        if npm update -g; then
            log_success "npm global packages updated"
        else
            log_warning "npm global packages update failed"
        fi
    else
        log_warning "npm not found, skipping"
    fi
}

install_pi_subagents_package() {
    if ! command -v pi &>/dev/null; then
        log_warning "pi not found, skipping Pi subagents package"
        return 0
    fi

    log_info "Ensuring Pi subagents package is installed..."
    if pi install "$PI_SUBAGENTS_PACKAGE"; then
        log_success "Pi subagents package installed"
    else
        log_warning "Pi subagents package install failed"
    fi
}

update_pi_coding_agent() {
    log_info "Updating Pi coding agent..."

    configure_npm_user_prefix

    if command -v pi &>/dev/null; then
        if pi update; then
            log_success "Pi coding agent updated"
            install_pi_subagents_package
            return 0
        fi
        log_warning "pi update failed, falling back to npm install"
    fi

    if command -v npm &>/dev/null; then
        if npm install -g @mariozechner/pi-coding-agent@latest; then
            log_success "Pi coding agent updated via npm"
        else
            log_warning "Pi coding agent update failed"
        fi
    else
        log_warning "npm not found, skipping Pi coding agent update"
    fi

    if command -v pi &>/dev/null; then
        if pi update --extensions; then
            log_success "Pi packages updated"
        else
            log_warning "Pi package update failed"
        fi
    fi

    install_pi_subagents_package
}

update_claude_code() {
    log_info "Updating Claude Code..."

    configure_npm_user_prefix
    if command -v npm &>/dev/null; then
        if npm install -g @anthropic-ai/claude-code@latest; then
            log_success "Claude Code updated"
        else
            log_warning "Claude Code update failed"
        fi
    else
        log_warning "npm not found, skipping Claude Code update"
    fi
}

update_oh_my_zsh() {
    log_info "Updating oh-my-zsh..."
    if [[ -x "$HOME/.oh-my-zsh/tools/upgrade.sh" ]]; then
        ZSH="$HOME/.oh-my-zsh" sh "$HOME/.oh-my-zsh/tools/upgrade.sh" || \
            log_warning "oh-my-zsh update failed"
        log_success "oh-my-zsh update complete"
    else
        log_warning "oh-my-zsh not found, skipping"
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

main() {
    log_info "Starting macOS maintenance..."

    check_macos
    load_homebrew
    update_homebrew_packages
    update_dotfiles
    update_npm_packages
    update_claude_code
    update_pi_coding_agent
    update_oh_my_zsh
    update_nvim_plugins

    log_success "Maintenance complete!"
}

main "$@"
