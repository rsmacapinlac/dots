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

get_latest_github_release_asset() {
    local repo=$1
    local pattern=$2

    curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=5" \
        | grep -om 1 "https://github.com/$repo/releases/download/[^\"]*$pattern[^\"]*" \
        || true
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

update_ai_support_tools() {
    log_info "Updating AI support tools..."

    load_homebrew
    configure_npm_user_prefix

    if command -v npm &>/dev/null; then
        npm install -g agent-browser@latest || log_warning "agent-browser update failed"
        if command -v agent-browser &>/dev/null; then
            agent-browser install || log_warning "agent-browser browser install failed"
        fi
    else
        log_warning "npm not found, skipping agent-browser update"
    fi

    if command -v brew &>/dev/null; then
        local brew_bin arch pattern url tmpdir binary
        brew_bin="$(brew --prefix)/bin"

        if brew list --formula gogcli &>/dev/null; then
            brew upgrade gogcli || log_warning "gogcli upgrade failed"
        else
            brew install gogcli || log_warning "gogcli install failed"
        fi

        case "$(uname -m)" in
            arm64)  arch="aarch64-darwin" ;;
            x86_64) arch="x86_64-darwin" ;;
            *) arch="" ;;
        esac
        if [[ -n "$arch" ]]; then
            pattern="himalaya.${arch}.tgz"
            url=$(get_latest_github_release_asset "pimalaya/himalaya" "$pattern")
            if [[ -n "$url" ]]; then
                tmpdir=$(mktemp -d)
                if curl -fsSL "$url" -o "$tmpdir/himalaya.tgz" && tar -xzf "$tmpdir/himalaya.tgz" -C "$tmpdir"; then
                    binary=$(find "$tmpdir" -type f -name himalaya | head -1)
                    if [[ -n "$binary" ]] && install -m 0755 "$binary" "$brew_bin/himalaya"; then
                        log_success "himalaya updated"
                    else
                        log_warning "himalaya binary not found in release archive"
                    fi
                else
                    log_warning "himalaya update failed"
                fi
                rm -rf "$tmpdir"
            else
                log_warning "Could not find himalaya release asset for $pattern"
            fi
        else
            log_warning "Unsupported architecture $(uname -m), skipping himalaya update"
        fi
    else
        log_warning "Homebrew not found, skipping gogcli/himalaya updates"
    fi
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

update_rmpc() {
    if ! command -v rmpc &>/dev/null; then
        log_warning "rmpc not installed, skipping update"
        return 0
    fi

    log_info "Updating rmpc..."

    local arch
    case "$(uname -m)" in
        arm64)  arch="aarch64-apple-darwin" ;;
        x86_64) arch="x86_64-apple-darwin" ;;
        *)
            log_warning "Unsupported architecture $(uname -m), skipping rmpc update"
            return 0
            ;;
    esac

    local latest_version current_version
    latest_version=$(curl -s "https://api.github.com/repos/mierak/rmpc/releases/latest" \
        | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/') || true
    current_version=$(rmpc --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) || true

    if [[ -z "$latest_version" ]]; then
        log_warning "Could not determine latest rmpc version, skipping update"
        return 0
    fi

    if [[ "$latest_version" == "$current_version" ]]; then
        log_info "rmpc already at latest version ($current_version)"
        return 0
    fi

    local url tmpdir
    url="https://github.com/mierak/rmpc/releases/download/v${latest_version}/rmpc-v${latest_version}-${arch}.tar.gz"
    tmpdir=$(mktemp -d)
    if curl -fsSL "$url" -o "$tmpdir/rmpc.tar.gz" \
        && tar -xzf "$tmpdir/rmpc.tar.gz" -C "$tmpdir" \
        && install -m 0755 "$tmpdir/rmpc" "$(brew --prefix)/bin/rmpc"; then
        log_success "rmpc updated to ${latest_version}"
    else
        log_warning "rmpc update failed"
    fi
    rm -rf "$tmpdir"
}

update_rvm() {
    log_info "Updating RVM..."
    if command -v rvm &>/dev/null; then
        rvm get stable || log_warning "RVM update failed"
        log_success "RVM updated"
    else
        log_warning "RVM not found, skipping"
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

update_tmux_plugins() {
    log_info "Updating tmux plugins..."
    local tpm_update="$HOME/.tmux/plugins/tpm/bin/update_plugins"
    if [[ -x "$tpm_update" ]]; then
        "$tpm_update" all || log_warning "tmux plugin update failed"
        log_success "tmux plugins updated"
    else
        log_warning "TPM not found, skipping tmux plugin update"
    fi
}

main() {
    log_info "Starting macOS maintenance..."

    check_macos
    load_homebrew
    update_homebrew_packages
    update_dotfiles
    update_npm_packages
    update_rvm
    update_rmpc
    update_ai_support_tools
    update_claude_code
    update_pi_coding_agent
    update_oh_my_zsh
    update_nvim_plugins
    update_tmux_plugins

    log_success "Maintenance complete!"
}

main "$@"
