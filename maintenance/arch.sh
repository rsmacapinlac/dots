#!/bin/bash
#
# System Maintenance Script - Keep dotfiles and packages up to date
#
# Run this regularly (weekly/monthly) to:
# - Update all Arch/AUR packages
# - Update dotfiles via rcup
# - Update development tools

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

# Update all Arch/AUR packages (removes --needed, forces updates)
update_system_packages() {
    log_info "Updating all system packages..."
    yay -Syu --noconfirm --answerdiff None --answerclean None --removemake
    log_success "System packages updated"
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

# Update npm global packages
update_npm_packages() {
    log_info "Checking npm global packages..."
    if command -v npm &> /dev/null; then
        # Try to update; if it fails due to permissions, provide helpful guidance
        if npm update -g 2>/dev/null; then
            log_success "npm global packages updated"
        else
            log_warning "npm global packages skipped (likely permission issue). To update npm globals, run: sudo npm update -g"
        fi
    else
        log_warning "npm not found, skipping"
    fi
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
    update_nvim_plugins

    log_success "Maintenance complete!"
}

main "$@"
