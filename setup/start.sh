#!/bin/bash
#
# Bootstrap script for Arch Linux Workstation Setup
#
# Run on a fresh Arch installation (see setup/archinstall/) after first boot.
#
# Usage:
#   ./start.sh
#   curl -fsSL https://raw.githubusercontent.com/rsmacapinlac/dots/main/setup/start.sh | bash
#
# This needs no SSH or GPG keys and can be run anywhere — setup/arch.sh clones
# everything over HTTPS. Restore secrets afterwards with `restore-secrets`, run
# from your key backup directory.
#
# Environment overrides:
#   DOTS_REPO   GitHub repo to pull setup/arch.sh from (default rsmacapinlac/dots)
#   DOTS_REF    Branch or tag to pull (default main) — useful for testing changes
#               that are not yet on main.

set -euo pipefail

DOTS_REPO="${DOTS_REPO:-rsmacapinlac/dots}"
DOTS_REF="${DOTS_REF:-main}"
SETUP_URL="${SETUP_URL:-https://raw.githubusercontent.com/${DOTS_REPO}/${DOTS_REF}/setup/arch.sh}"

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

# Check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Check internet connectivity
check_internet() {
    log_info "Checking internet connectivity..."
    if ! ping -c 1 github.com &> /dev/null; then
        log_error "No internet connection. Please check your network and try again."
        exit 1
    fi
    log_success "Internet connectivity confirmed"
}

# Confirm sudo works now rather than failing partway through a long install.
check_sudo() {
    log_info "Checking sudo access..."
    if ! command -v sudo &> /dev/null; then
        log_error "sudo is not installed. Install it and add $USER to the wheel group."
        exit 1
    fi
    if ! sudo -v; then
        log_error "Cannot obtain sudo privileges for $USER."
        exit 1
    fi
    log_success "sudo access confirmed"
}

# Download and run the main setup script.
#
# Downloads to a file rather than piping into bash, for two reasons:
#
#   1. Under `curl ... | bash`, BASH_SOURCE[0] is unset and $0 is "bash", so
#      arch.sh's `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` guard is false, main()
#      never runs, and the script exits 0 having done nothing.
#   2. A piped script shares its stdin with the pipe, so any `read -p` prompt
#      consumes the script's own remaining text instead of user input.
#
# stdin is reattached to the terminal so arch.sh's interactive prompts still
# work when this script is itself invoked through `curl | bash`.
run_setup() {
    local script stdin_src="" status=0
    script="$(mktemp -t arch-setup.XXXXXX.sh)"

    log_info "Downloading setup script from ${DOTS_REPO}@${DOTS_REF}..."
    if ! curl -fsSL "$SETUP_URL" -o "$script"; then
        rm -f "$script"
        log_error "Failed to download setup script from $SETUP_URL"
        exit 1
    fi

    if [[ ! -s $script ]]; then
        rm -f "$script"
        log_error "Downloaded setup script is empty"
        exit 1
    fi

    if [[ -t 0 ]]; then
        : # stdin is already a terminal; nothing to reattach
    elif ( : < /dev/tty ) 2>/dev/null; then
        # Piped invocation with a controlling terminal. Test by opening /dev/tty
        # rather than with `-r`: the device node is readable by permission even
        # when no controlling terminal exists, and the open then fails at runtime.
        stdin_src="/dev/tty"
    else
        log_warning "No terminal available; any interactive prompt in the setup script will fail."
    fi

    log_info "Running main setup script..."

    # `|| status=$?` keeps set -e from terminating us here, so a failure is
    # reported along with the script's location instead of vanishing. A RETURN
    # trap would not fire at all in that case.
    if [[ -n $stdin_src ]]; then
        bash "$script" "$@" < "$stdin_src" || status=$?
    else
        bash "$script" "$@" || status=$?
    fi

    if (( status != 0 )); then
        log_error "Setup script failed (exit $status)."
        log_error "Downloaded script kept for inspection: $script"
        exit "$status"
    fi

    rm -f "$script"
}

# Main function
main() {
    log_info "Starting Arch Linux Workstation Setup Bootstrap..."

    check_not_root
    check_internet
    check_sudo
    run_setup "$@"

    log_success "Setup completed! Please reboot your system."
    log_info "Secrets were not restored. Run 'restore-secrets' from your key"
    log_info "backup directory to set up SSH, GPG, and the password store."
}

# Run main function
main "$@"
