#!/bin/bash
#
# Bootstrap entry point for an Arch workstation rebuild.
#
# The same command is used at both phases of a rebuild; the script works out
# which one it is from where it is running:
#
#   on the Arch live ISO   -> pick an archinstall profile and install the base
#                             system, then eject the ISO and reboot
#   on the installed system -> download and run setup/arch.sh to build the
#                             workstation
#
# Usage, identical at both phases:
#   curl -fsSL https://raw.githubusercontent.com/rsmacapinlac/dots/main/setup/start.sh | bash
#
# The two phases have opposite privilege requirements — archinstall must run as
# root, setup/arch.sh must not — so each branch checks for itself.
#
# Secrets are never handled here. SSH keys, GPG keys and the password store are
# restored by hand afterwards; setup/arch.sh documents the steps at the end of
# configure_security().
#
# Environment overrides:
#   DOTS_REPO         GitHub repo to pull from (default rsmacapinlac/dots)
#   DOTS_REF          Branch or tag (default main) — for testing unmerged work
#   DOTS_FORCE_PHASE  "iso" or "system" — skip detection, for testing only

set -euo pipefail

# Empty when piped into bash (`curl ... | bash`), set when run from a file.
# prompt() uses this to decide whether stdin is safe to read from.
SCRIPT_FILE="${BASH_SOURCE[0]:-}"

DOTS_REPO="${DOTS_REPO:-rsmacapinlac/dots}"
DOTS_REF="${DOTS_REF:-main}"
RAW_BASE="https://raw.githubusercontent.com/${DOTS_REPO}/${DOTS_REF}"
SETUP_URL="${SETUP_URL:-${RAW_BASE}/setup/arch.sh}"
API_BASE="https://api.github.com/repos/${DOTS_REPO}/contents/setup/archinstall"

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

# ---------------------------------------------------------------- detection --

# The live ISO mounts its filesystems under /run/archiso and sets the hostname
# to "archiso". Either alone is a reasonable signal; the hostname is weaker
# because it is configurable, so it only acts as a fallback.
on_archiso() {
    [[ ${DOTS_FORCE_PHASE:-} == iso ]] && return 0
    [[ ${DOTS_FORCE_PHASE:-} == system ]] && return 1
    [[ -d /run/archiso ]] && return 0
    [[ $(cat /etc/hostname 2>/dev/null) == archiso ]] && return 0
    return 1
}

# ------------------------------------------------------------------ shared --

check_internet() {
    log_info "Checking internet connectivity..."
    if ! ping -c 1 github.com &> /dev/null; then
        log_error "No internet connection. Please check your network and try again."
        log_error "On the live ISO, use 'iwctl' for Wi-Fi; Ethernet should be automatic."
        exit 1
    fi
    log_success "Internet connectivity confirmed"
}

# Read a line of input, choosing a source that is safe for how we were invoked.
#
# Under `curl ... | bash` stdin is the pipe carrying this script's own text, so
# a bare `read` consumes the remaining script instead of user input — the same
# trap that makes `read -p` unusable in a piped installer. When the script was
# read from a real file, stdin carries no script text and is safe to use, which
# also makes this testable with redirected input.
prompt() {
    local varname=$1 message=$2
    if [[ -t 0 ]]; then
        read -r -p "$message" "$varname"
    elif [[ -n $SCRIPT_FILE ]]; then
        read -r -p "$message" "$varname"
    elif ( : < /dev/tty ) 2>/dev/null; then
        read -r -p "$message" "$varname" < /dev/tty
    else
        log_error "No terminal available to read input."
        exit 1
    fi
}

# Run a child command with stdin attached to the terminal.
#
# Under `curl ... | bash` this script's stdin is the pipe carrying its own
# text. A child inherits that, so anything reading the keyboard sees the pipe
# instead of the terminal: archinstall's TUI draws correctly, because stdout is
# still the terminal, but arrow keys and every other keypress go nowhere.
run_interactive() {
    if [[ -t 0 ]]; then
        "$@"
    elif ( : < /dev/tty ) 2>/dev/null; then
        "$@" < /dev/tty
    else
        log_error "No terminal available; cannot run an interactive command."
        log_error "Re-run this script from a terminal rather than through a pipe."
        exit 1
    fi
}

# ------------------------------------------------------- phase 1: live ISO --

# List the archinstall profiles in the repo. Falls back to a manual entry if
# the API is unreachable or rate-limited, so a bad network never dead-ends.
list_profiles() {
    curl -fsSL "$API_BASE" 2>/dev/null \
        | grep -oE '"name": *"[^"]+\.json"' \
        | sed 's/.*"\([^"]*\.json\)"/\1/' \
        | sort
}

run_installer_phase() {
    log_info "Running on the Arch live ISO — base system installation."

    if [[ $EUID -ne 0 ]]; then
        log_error "The installer phase must run as root. On the live ISO you already are."
        exit 1
    fi

    check_internet

    local profiles=() choice
    mapfile -t profiles < <(list_profiles)

    echo
    echo "  Available archinstall profiles:"
    if (( ${#profiles[@]} > 0 )); then
        local i=1
        for p in "${profiles[@]}"; do
            echo "    $i) $p"
            i=$((i + 1))
        done
    else
        log_warning "Could not list profiles from GitHub; enter a filename manually."
    fi
    echo "    i) run archinstall interactively (no profile)"
    echo "    s) drop to a shell and do it by hand"
    echo

    prompt choice "  Choose: "

    case "$choice" in
        i|I)
            log_info "Starting archinstall with no profile..."
            run_interactive archinstall
            ;;
        s|S)
            log_info "Dropping to a shell. Re-run this script when you are ready."
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
            local profile="${profiles[$idx]}"
            local dest="/tmp/${profile}"

            log_info "Downloading profile ${profile}..."
            if ! curl -fsSL "${RAW_BASE}/setup/archinstall/${profile}" -o "$dest"; then
                log_error "Could not download ${profile}"
                exit 1
            fi

            log_warning "This profile WIPES its target disk. Check it before continuing:"
            grep -E '"device"|"hostname"' "$dest" | sed 's/^/      /'
            echo
            local confirm
            prompt confirm "  Type 'yes' to run archinstall with this profile: "
            [[ $confirm == yes ]] || { log_info "Aborted."; exit 0; }

            log_info "Running archinstall --config $dest ..."
            run_interactive archinstall --config "$dest"
            ;;
    esac

    echo
    log_success "Base installation step finished."
    log_warning "Before rebooting, eject the ISO from the HOST or the installer boots again:"
    log_warning "    virsh change-media <domain> sda --eject --config   # VM"
    log_warning "    (bare metal: remove the USB stick)"
    echo
    log_info "Then reboot, log in as your user, and run this same command again"
    log_info "to build the workstation:"
    echo
    echo "    curl -fsSL ${RAW_BASE}/setup/start.sh | bash"
    echo
}

# ----------------------------------------------- phase 2: installed system --

check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
        exit 1
    fi
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
# stdin is reattached to the terminal so prompts still work when this script is
# itself invoked through `curl | bash`.
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

run_workstation_phase() {
    log_info "Running on an installed system — workstation setup."

    check_not_root
    check_internet
    check_sudo
    run_setup "$@"

    log_success "Setup completed! Please reboot your system."
}

# ------------------------------------------------------------------- main --

main() {
    log_info "Arch Workstation Bootstrap (${DOTS_REPO}@${DOTS_REF})"

    if on_archiso; then
        run_installer_phase
    else
        run_workstation_phase "$@"
    fi
}

main "$@"
