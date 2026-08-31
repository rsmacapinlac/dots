#!/bin/bash
# Dispatcher for the two-stage Arch workstation bootstrap.
#
# Run the same command on the live ISO and after the first reboot:
#   curl -fsSL https://raw.githubusercontent.com/rsmacapinlac/dots/main/setup/start.sh | bash

set -euo pipefail

DOTS_REPO="${DOTS_REPO:-rsmacapinlac/dots}"
export DOTS_REPO
export DOTS_REF="${DOTS_REF:-main}"
RAW_BASE="https://raw.githubusercontent.com/${DOTS_REPO}/${DOTS_REF}"
ARCHINSTALL_URL="${ARCHINSTALL_URL:-${RAW_BASE}/setup/archinstall/install.sh}"
CORE_URL="${CORE_URL:-${RAW_BASE}/setup/arch.sh}"
COMMON_URL="${COMMON_URL:-${RAW_BASE}/setup/lib/arch-common.sh}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

on_archiso() {
    [[ ${DOTS_FORCE_PHASE:-} == iso ]] && return 0
    [[ ${DOTS_FORCE_PHASE:-} == system ]] && return 1
    [[ -d /run/archiso ]] && return 0
    [[ $(cat /etc/hostname 2>/dev/null) == archiso ]]
}

check_internet() {
    log_info "Checking internet connectivity..."
    if ! ping -c 1 github.com &>/dev/null; then
        log_error "No internet connection."
        exit 1
    fi
}

run_with_terminal() {
    if [[ -t 0 ]]; then
        "$@"
    elif ( : < /dev/tty ) 2>/dev/null; then
        "$@" < /dev/tty
    else
        log_warning "No controlling terminal is available; prompts may fail."
        "$@"
    fi
}

download() {
    local url=$1 destination=$2
    if ! curl -fsSL "$url" -o "$destination"; then
        log_error "Failed to download $url"
        exit 1
    fi
    if [[ ! -s $destination ]]; then
        log_error "Downloaded an empty file from $url"
        exit 1
    fi
}

run_archinstall_phase() {
    if [[ $EUID -ne 0 ]]; then
        log_error "The live-ISO phase must run as root."
        exit 1
    fi

    local temp_dir script status=0
    temp_dir=$(mktemp -d -t dots-archinstall.XXXXXX)
    script="$temp_dir/install.sh"

    download "$ARCHINSTALL_URL" "$script"
    chmod +x "$script"
    export RAW_BASE
    export API_BASE="https://api.github.com/repos/${DOTS_REPO}/contents/setup/archinstall"
    run_with_terminal bash "$script" || status=$?
    rm -rf "$temp_dir"
    (( status == 0 )) || exit "$status"
}

run_core_phase() {
    if [[ $EUID -eq 0 ]]; then
        log_error "The installed-system phase must run as a regular user."
        exit 1
    fi
    if ! command -v sudo &>/dev/null; then
        log_error "sudo is not installed. Install it and add the user to wheel."
        exit 1
    fi
    sudo -v

    local temp_dir script common status=0
    temp_dir=$(mktemp -d -t dots-core.XXXXXX)
    script="$temp_dir/arch.sh"
    common="$temp_dir/lib/arch-common.sh"
    mkdir -p "$temp_dir/lib"

    download "$CORE_URL" "$script"
    download "$COMMON_URL" "$common"
    chmod +x "$script"
    run_with_terminal bash "$script" || status=$?

    if (( status != 0 )); then
        log_error "Core setup failed with exit $status."
        log_error "Downloaded core installer: $script"
        exit "$status"
    fi

    rm -rf "$temp_dir"
    log_success "Core workstation setup completed."
    log_info "Reboot to enter the Hyprland desktop."
    log_info "After login, run ~/workspace/dots/setup/applications.sh for optional software."
}

main() {
    log_info "Arch workstation bootstrap (${DOTS_REPO}@${DOTS_REF})"
    check_internet
    if on_archiso; then
        run_archinstall_phase
    else
        run_core_phase
    fi
}

main "$@"
