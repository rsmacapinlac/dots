#!/bin/bash
#
# System Maintenance Script - Keep dotfiles and packages up to date
#
# Run this regularly (weekly/monthly) to:
# - Update all Arch/AUR packages
# - Update dotfiles via rcup
# - Update development tools
# - Update Pi coding agent

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

# Install/update Pi directly from upstream GitHub releases.  This is needed
# when the AUR package lags behind upstream (or is marked out-of-date).
update_pi_from_github_release() {
    local current_version latest_tag latest_version arch asset_url tmpdir

    if ! command -v curl &> /dev/null || ! command -v python &> /dev/null; then
        log_warning "curl/python not found, cannot check upstream Pi release"
        return 1
    fi

    current_version="$(pi --version 2>/dev/null || echo 0.0.0)"
    latest_tag="$(python - <<'PY'
import json, urllib.request
with urllib.request.urlopen("https://api.github.com/repos/badlogic/pi-mono/releases/latest", timeout=20) as r:
    print(json.load(r)["tag_name"])
PY
)"
    latest_version="${latest_tag#v}"

    if command -v vercmp &> /dev/null && [[ "$(vercmp "$latest_version" "$current_version")" -le 0 ]]; then
        log_success "Pi coding agent is already up to date ($current_version)"
        return 0
    fi

    case "$(uname -m)" in
        x86_64) arch="x64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)
            log_warning "Unsupported architecture for Pi upstream release: $(uname -m)"
            return 1
            ;;
    esac

    asset_url="https://github.com/badlogic/pi-mono/releases/download/${latest_tag}/pi-linux-${arch}.tar.gz"
    tmpdir="$(mktemp -d)"

    log_info "Installing Pi ${latest_version} from upstream GitHub release..."
    if ! curl -fsSL "$asset_url" -o "$tmpdir/pi.tar.gz" || \
       ! tar -xzf "$tmpdir/pi.tar.gz" -C "$tmpdir" || \
       ! sudo rsync -a --delete "$tmpdir/pi/" /opt/pi-coding-agent/ || \
       ! sudo ln -sfn ../../opt/pi-coding-agent/pi /usr/bin/pi; then
        rm -rf "$tmpdir"
        return 1
    fi

    rm -rf "$tmpdir"
    log_success "Pi coding agent updated to $(pi --version)"
}

# Update Pi coding agent and installed Pi packages
update_pi_coding_agent() {
    log_info "Updating Pi coding agent..."

    if command -v pi &> /dev/null; then
        local pi_path
        pi_path="$(command -v pi)"

        # Arch/AUR installs are owned by pacman and `pi update` cannot
        # self-update them. Try yay first, then bypass stale AUR packages by
        # installing the latest official upstream release into /opt/pi-coding-agent.
        if pacman -Qo "$pi_path" &> /dev/null; then
            log_info "Pi is managed by pacman/AUR; checking pi-coding-agent via yay..."
            local current_pi_version aur_pi_version aur_pi_info
            current_pi_version="$(pi --version 2>/dev/null || echo 0.0.0)"
            aur_pi_info="$(yay -Si pi-coding-agent 2>/dev/null || true)"
            aur_pi_version="$(awk -F': +' '/^Version/ {print $2; exit}' <<< "$aur_pi_info")"
            aur_pi_version="${aur_pi_version%%-*}"

            if [[ -n "$aur_pi_version" ]] && command -v vercmp &> /dev/null && [[ "$(vercmp "$aur_pi_version" "$current_pi_version")" -gt 0 ]]; then
                if yay -S --noconfirm --answerdiff None --answerclean None pi-coding-agent; then
                    log_success "Pi AUR package updated"
                else
                    log_warning "Pi coding agent package update failed"
                fi
            else
                log_info "Skipping AUR Pi install; AUR is not newer than installed Pi ($current_pi_version)"
            fi

            if ! update_pi_from_github_release; then
                log_warning "Pi upstream release update failed"
            fi

            # Still update installed Pi packages/extensions from settings.json.
            if pi update --extensions; then
                log_success "Pi packages updated"
            else
                log_warning "Pi package update failed"
            fi
            return 0
        fi

        # Prefer Pi's own updater for npm/standalone installs so both Pi itself
        # and any non-pinned Pi packages from ~/.pi/agent/settings.json are kept current.
        if pi update; then
            log_success "Pi coding agent updated"
            return 0
        fi
        log_warning "pi update failed, falling back to npm install"
    fi

    if command -v npm &> /dev/null; then
        if sudo npm install -g @mariozechner/pi-coding-agent@latest; then
            log_success "Pi coding agent updated via npm"
        else
            log_warning "Pi coding agent update failed"
        fi
    else
        log_warning "npm not found, skipping Pi coding agent update"
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
    update_pi_coding_agent
    update_nvim_plugins

    log_success "Maintenance complete!"
}

main "$@"
