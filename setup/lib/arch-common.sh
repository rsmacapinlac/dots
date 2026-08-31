#!/bin/bash
# Shared helpers for the installed-system Arch provisioning scripts.

if [[ ${DOTS_ARCH_COMMON_LOADED:-0} == 1 ]]; then
    return 0
fi
DOTS_ARCH_COMMON_LOADED=1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

refresh_runtime_path() {
    local dir
    for dir in /usr/bin/core_perl /usr/bin/vendor_perl /usr/bin/site_perl; do
        if [[ -d $dir && ":$PATH:" != *":$dir:"* ]]; then
            PATH="$PATH:$dir"
            export PATH
            log_info "Added $dir to PATH (installed during this run)"
        fi
    done
}

yay_install() {
    refresh_runtime_path
    yay -S --needed --noconfirm --answerdiff None --answerclean None "$@"
}

configure_pacman_parallel_downloads() {
    local conf=/etc/pacman.conf

    if grep -qE '^[[:space:]]*ParallelDownloads' "$conf"; then
        log_info "ParallelDownloads already enabled"
        return 0
    fi

    log_info "Enabling parallel package downloads..."
    if grep -qE '^[[:space:]]*#[[:space:]]*ParallelDownloads' "$conf"; then
        sudo sed -i 's/^[[:space:]]*#[[:space:]]*ParallelDownloads.*/ParallelDownloads = 5/' "$conf"
    else
        sudo sed -i '/^\[options\]/a ParallelDownloads = 5' "$conf"
    fi

    if grep -qE '^[[:space:]]*ParallelDownloads' "$conf"; then
        log_success "ParallelDownloads enabled"
    else
        log_warning "Could not enable ParallelDownloads; downloads will be serial"
    fi
}

remove_build_dependencies() {
    log_info "Removing orphaned build dependencies..."
    if yay -Yc --noconfirm 2>/dev/null; then
        log_success "Build dependencies cleaned up"
    else
        log_info "Nothing to clean up"
    fi
}

check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Run this script as a regular user with sudo privileges."
        exit 1
    fi
}

detect_arch() {
    if [[ ! -r /etc/os-release ]]; then
        log_error "Cannot detect the Linux distribution."
        exit 1
    fi

    local distro pretty_name
    distro=$( . /etc/os-release; printf '%s' "${ID:-}" )
    pretty_name=$( . /etc/os-release; printf '%s' "${PRETTY_NAME:-$distro}" )
    log_info "Detected distribution: $pretty_name"

    if [[ $distro != arch ]]; then
        log_error "This script only supports Arch Linux."
        exit 1
    fi
}

check_sudo() {
    if ! command -v sudo &>/dev/null; then
        log_error "sudo is not installed."
        exit 1
    fi
    sudo -v
}

SUDO_NOPASSWD_FILE="/etc/sudoers.d/99-dots-setup"
SUDO_WATCHER_PID=""

enable_passwordless_sudo() {
    log_info "Enabling passwordless sudo for this installer run..."
    check_sudo
    sudo rm -f "$SUDO_NOPASSWD_FILE"

    local tmp
    tmp=$(mktemp)
    printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$USER" > "$tmp"
    if ! sudo visudo -c -f "$tmp" >/dev/null; then
        rm -f "$tmp"
        log_error "Refusing to install an invalid sudoers file."
        exit 1
    fi

    sudo install -m 0440 -o root -g root "$tmp" "$SUDO_NOPASSWD_FILE"
    rm -f "$tmp"

    (
        while kill -0 "$$" 2>/dev/null; do sleep 5; done
        sudo -n rm -f "$SUDO_NOPASSWD_FILE" 2>/dev/null
    ) &
    SUDO_WATCHER_PID=$!
}

disable_passwordless_sudo() {
    if [[ -n $SUDO_WATCHER_PID ]]; then
        kill "$SUDO_WATCHER_PID" 2>/dev/null || true
        SUDO_WATCHER_PID=""
    fi

    if [[ -e $SUDO_NOPASSWD_FILE ]]; then
        if sudo -n rm -f "$SUDO_NOPASSWD_FILE" 2>/dev/null; then
            log_info "Passwordless sudo rule removed."
        else
            log_warning "Remove the leftover sudo rule manually:"
            log_warning "    sudo rm -f $SUDO_NOPASSWD_FILE"
        fi
    fi
}

install_aur_helper() {
    if command -v yay &>/dev/null; then
        log_info "yay is already installed"
        return 0
    fi

    log_info "Installing Yay and its build prerequisites..."
    sudo pacman -S --needed --noconfirm base-devel git
    refresh_runtime_path

    local build_dir
    build_dir=$(mktemp -d -t yay-build.XXXXXX)
    git clone https://aur.archlinux.org/yay.git "$build_dir"
    (
        cd "$build_dir"
        makepkg -f -s --noconfirm
        sudo pacman -U --noconfirm yay-*.pkg.tar.zst
    )
    rm -rf "$build_dir"
    log_success "Yay installed"
}

upgrade_system() {
    log_info "Performing a full system upgrade..."
    yay -Syu --noconfirm --answerdiff None --answerclean None
    log_success "System upgrade completed"
}

begin_arch_install() {
    check_not_root
    detect_arch
    trap disable_passwordless_sudo EXIT
    enable_passwordless_sudo
}
