#!/bin/bash
#
# System Maintenance Script - Keep dotfiles and packages up to date
#
# Run this regularly (weekly/monthly) to:
# - Update all Arch/AUR packages
# - Update dotfiles via rcup
# - Update development tools
# - Update mise-managed development tools

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

# Directory tree that npm manages out-of-band (e.g. `sudo npm update -g` below).
# Files here can drift from pacman's `npm` package and make `yay -Syu` abort
# with "exists in filesystem" conflicts on the next run.
NPM_MODULES_DIR="/usr/lib/node_modules"

# Update all Arch/AUR packages (removes --needed, forces updates)
update_system_packages() {
    log_info "Updating all system packages..."

    local log_file
    log_file="$(mktemp)"

    if yay -Syu --noconfirm --answerdiff None --answerclean None --removemake \
        2>&1 | tee "$log_file"; then
        rm -f "$log_file"
        log_success "System packages updated"
        return 0
    fi

    # Recover from npm file-ownership conflicts caused by `sudo npm update -g`
    # shadowing pacman's `npm` package. Only retry when the upgrade failed on
    # "exists in filesystem" AND every conflicting path lives under the npm
    # modules tree, so we never blindly overwrite unrelated packages.
    local conflicts
    conflicts="$(grep -oE '/[^ ]+ exists in filesystem' "$log_file" | awk '{print $1}')"
    rm -f "$log_file"

    if [[ -z "$conflicts" ]]; then
        log_error "System package update failed"
        return 1
    fi

    if grep -qv "^${NPM_MODULES_DIR}/" <<< "$conflicts"; then
        log_error "System upgrade hit file conflicts outside ${NPM_MODULES_DIR}; not auto-overwriting. Resolve manually."
        return 1
    fi

    log_warning "npm file conflicts under ${NPM_MODULES_DIR} detected; retrying upgrade with --overwrite..."
    if yay -Syu --noconfirm --answerdiff None --answerclean None --removemake \
        --overwrite "${NPM_MODULES_DIR}/*"; then
        log_success "System packages updated (resolved npm file conflicts)"
    else
        log_error "System package update failed even after overwriting npm conflicts"
        return 1
    fi
}

# Update dotfiles via rcup
update_dotfiles() {
    log_info "Updating dotfiles via rcup..."
    if command -v rcup &> /dev/null; then
        rcup -v
        log_success "Dotfiles updated"
    else
        log_warning "rcup not found, skipping dotfiles update"
    fi
}

# Configure user-level npm globals for tools that are not yet managed by mise.
configure_npm_user_prefix() {
    if ! command -v npm &> /dev/null; then
        log_warning "npm not found, skipping npm user prefix setup"
        return 0
    fi

    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global"
    export PATH="$HOME/.npm-global/bin:$PATH"
}

# Update npm global packages (requires sudo for system-wide packages)
update_npm_packages() {
    log_info "Updating npm global packages..."
    if command -v npm &> /dev/null; then
        # Use sudo for global npm updates (packages installed in /usr/lib/node_modules)
        if sudo npm update -g; then
            log_success "npm global packages updated"
        else
            log_warning "npm global packages update failed"
        fi
    else
        log_warning "npm not found, skipping"
    fi
}

# Ensure AI packages are present. Version upgrades are handled by the
# `yay -Syu` in update_system_packages; this step exists so machines
# provisioned before these were added pick them up.
update_ai_packages() {
    log_info "Ensuring AI packages..."

    if ! command -v yay &>/dev/null; then
        log_warning "yay not found, skipping AI package check"
        return 0
    fi

    local pkg
    for pkg in claude-desktop chatgpt-desktop; do
        if pacman -Q "$pkg" &>/dev/null; then
            log_info "$pkg already installed"
        elif yay -S --needed --noconfirm --answerdiff None --answerclean None --removemake "$pkg"; then
            log_success "$pkg installed"
        else
            log_warning "Failed to install $pkg"
        fi
    done
}

update_mise_tools() {
    log_info "Updating mise-managed tools..."

    if ! command -v mise &>/dev/null; then
        yay -S --needed --noconfirm mise || {
            log_warning "mise install failed"
            return 0
        }
    fi

    export PATH="$HOME/.local/bin:$PATH"
    "$HOME/bin/install-mise-tools"
    MISE_MINIMUM_RELEASE_AGE=0 mise up
    log_success "mise-managed tools updated"
}

# Update Neovim plugins via lazy.nvim
update_nvim_plugins() {
    log_info "Updating Neovim plugins..."
    if command -v nvim &> /dev/null; then
        nvim --headless -c "Lazy! sync" -c "qa" 2>/dev/null || log_warning "Failed to update Nvim plugins (Nvim may not be running)"
    else
        log_warning "nvim not found, skipping"
    fi
}

# Main execution
main() {
    log_info "Starting system maintenance..."

    update_system_packages
    update_dotfiles
    update_npm_packages
    update_ai_packages
    update_mise_tools
    update_nvim_plugins

    log_success "Maintenance complete!"
}

main "$@"
