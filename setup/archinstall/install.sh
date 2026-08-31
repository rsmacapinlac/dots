#!/bin/bash
# Live-ISO Archinstall profile selector used by setup/start.sh.

set -euo pipefail

DOTS_REPO="${DOTS_REPO:-rsmacapinlac/dots}"
DOTS_REF="${DOTS_REF:-main}"
RAW_BASE="${RAW_BASE:-https://raw.githubusercontent.com/${DOTS_REPO}/${DOTS_REF}}"
API_BASE="${API_BASE:-https://api.github.com/repos/${DOTS_REPO}/contents/setup/archinstall}"
SCRIPT_FILE="${BASH_SOURCE[0]:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

prompt() {
    local varname=$1 message=$2
    if [[ -t 0 || -n $SCRIPT_FILE ]]; then
        read -r -p "$message" "$varname"
    elif ( : < /dev/tty ) 2>/dev/null; then
        read -r -p "$message" "$varname" < /dev/tty
    else
        log_error "No terminal is available to read input."
        exit 1
    fi
}

run_interactive() {
    if [[ -t 0 ]]; then
        "$@"
    elif ( : < /dev/tty ) 2>/dev/null; then
        "$@" < /dev/tty
    else
        log_error "No terminal is available for Archinstall."
        exit 1
    fi
}

check_internet() {
    log_info "Checking internet connectivity..."
    if ! ping -c 1 github.com &>/dev/null; then
        log_error "No internet connection. Use iwctl for Wi-Fi and try again."
        exit 1
    fi
}

list_profiles() {
    curl -fsSL "$API_BASE" 2>/dev/null \
        | grep -oE '"name": *"[^"]+\.json"' \
        | sed 's/.*"\([^"]*\.json\)"/\1/' \
        | sort
}

main() {
    if [[ $EUID -ne 0 ]]; then
        log_error "The live-ISO installer must run as root."
        exit 1
    fi

    check_internet

    local profiles=() choice
    mapfile -t profiles < <(list_profiles)

    echo
    echo "  Available Archinstall profiles:"
    if (( ${#profiles[@]} > 0 )); then
        local i=1 profile
        for profile in "${profiles[@]}"; do
            echo "    $i) $profile"
            i=$((i + 1))
        done
    else
        log_warning "Could not list profiles from GitHub."
    fi
    echo "    i) run Archinstall interactively"
    echo "    s) exit to the live-ISO shell"
    echo

    prompt choice "  Choose: "
    case "$choice" in
        i|I)
            run_interactive archinstall
            ;;
        s|S)
            log_info "Returning to the live-ISO shell."
            exit 0
            ;;
        ''|*[!0-9]*)
            log_error "Not a valid choice: $choice"
            exit 1
            ;;
        *)
            local idx=$((choice - 1))
            if (( idx < 0 || idx >= ${#profiles[@]} )); then
                log_error "Choice out of range: $choice"
                exit 1
            fi

            local selected=${profiles[$idx]}
            local profile_path="/tmp/$selected"
            log_info "Downloading $selected..."
            curl -fsSL "${RAW_BASE}/setup/archinstall/${selected}" -o "$profile_path"

            log_warning "This profile WIPES its target disk:"
            grep -E '"device"|"hostname"' "$profile_path" | sed 's/^/      /'
            echo

            local confirm
            prompt confirm "  Type 'yes' to continue: "
            [[ $confirm == yes ]] || { log_info "Aborted."; exit 0; }
            run_interactive archinstall --config "$profile_path"
            ;;
    esac

    echo
    log_success "Base installation finished."
    log_warning "Eject the ISO from the host or remove the USB stick before rebooting."
    log_info "After rebooting, log in at the TTY and run the same start.sh command."
}

main "$@"
