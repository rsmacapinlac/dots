#!/bin/bash
# Optional application installer for an already provisioned Arch workstation.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=setup/lib/arch-common.sh
source "$SCRIPT_DIR/lib/arch-common.sh"

readonly APPLICATION_GROUPS=(
    development
    productivity
    media
    mail
    ai-desktop
    gaming
    virtualization
    security
    work
    syncthing
)

usage() {
    cat <<'EOF'
Usage: setup/applications.sh [GROUP ... | all]

With no arguments, opens an fzf multi-select menu. Available groups:
  development    Go, Node.js/npm, and Cursor
  productivity   GnuCash, Obsidian, Slack, Zoom, and Aether
  media          Chromium, yt-dlp, VLC, cliamp, Beets, HandBrake, and OBS
  mail           Neomutt, isync, msmtp, Notmuch, viewers, and archive tools
  ai-desktop     Claude Desktop and ChatGPT Desktop
  gaming         Steam and its runtime dependencies
  virtualization QEMU, libvirt, virt-manager, and supporting tools
  security       Bitwarden Desktop, Mise-managed bw, and WireGuard
  work           Work applications (Citrix Workspace)
  syncthing      Syncthing and its user service
  all            Every optional group

Account-bound apps are not installed here. They are useless until you sign in,
so they ship as one-shot installers you run by hand after the desktop is up:
  setup/services/nextcloud.sh   Nextcloud sync client
  setup/services/todoist.sh     Todoist as a Chromium web app
EOF
}

group_exists() {
    local wanted=$1 group
    for group in "${APPLICATION_GROUPS[@]}"; do
        [[ $group == "$wanted" ]] && return 0
    done
    return 1
}

select_groups() {
    if ! command -v fzf &>/dev/null; then
        log_error "fzf is required for interactive selection. Pass group names explicitly."
        exit 1
    fi

    local choices
    choices=$(cat <<'EOF' | fzf --multi --layout=reverse --border \
        --header='TAB/Shift-TAB select · ENTER install · ESC cancel' \
        --prompt='Optional groups > ' || true
development	Go, Node.js/npm, and Cursor
productivity	GnuCash, Obsidian, Slack, Zoom, and Aether
media	Chromium, yt-dlp, VLC, cliamp, Beets, HandBrake, and OBS
mail	Neomutt, isync, msmtp, Notmuch, viewers, and archive tools
ai-desktop	Claude Desktop and ChatGPT Desktop
gaming	Steam and its runtime dependencies
virtualization	QEMU, libvirt, virt-manager, and supporting tools
security	Bitwarden Desktop, Mise-managed bw, and WireGuard
work	Work applications (Citrix Workspace)
syncthing	Syncthing and its user service
EOF
    )

    [[ -n $choices ]] || return 0
    printf '%s\n' "$choices" | cut -f1
}

normalize_groups() {
    local requested=("$@") group
    if (( ${#requested[@]} == 1 )) && [[ ${requested[0]} == all ]]; then
        printf '%s\n' "${APPLICATION_GROUPS[@]}"
        return 0
    fi

    local -A seen=()
    for group in "${requested[@]}"; do
        if [[ $group == all ]]; then
            log_error "'all' cannot be combined with other groups." >&2
            return 1
        fi
        if ! group_exists "$group"; then
            log_error "Unknown application group: $group" >&2
            return 1
        fi
        if [[ -z ${seen[$group]:-} ]]; then
            printf '%s\n' "$group"
            seen[$group]=1
        fi
    done
}

install_development() {
    log_info "Installing development applications..."
    yay_install go nodejs npm cursor-bin
}

install_productivity() {
    log_info "Installing productivity applications..."
    yay_install \
        gnucash \
        obsidian \
        slack-desktop \
        zoom \
        aether
}

install_media() {
    log_info "Installing media applications..."
    yay -Rns --noconfirm totem totem-plugins 2>/dev/null || true
    yay_install \
        chromium \
        yt-dlp \
        vlc \
        vlc-plugins-all \
        libao \
        cliamp \
        beets \
        python-discogs-client \
        handbrake \
        obs-studio \
        v4l2loopback-dkms

    echo v4l2loopback | sudo tee /etc/modules-load.d/v4l2loopback.conf >/dev/null
    sudo modprobe v4l2loopback 2>/dev/null || \
        log_warning "v4l2loopback will be loaded after the next reboot"
}

install_mail() {
    log_info "Installing terminal mail applications..."
    yay_install \
        neomutt \
        isync \
        msmtp \
        notmuch \
        urlscan \
        lynx \
        w3m \
        imagemagick \
        kitty-terminfo \
        feh \
        zathura \
        zathura-pdf-mupdf \
        zathura-ps \
        zathura-djvu \
        zathura-cb \
        libreoffice-fresh \
        evince \
        unzip \
        unrar \
        7zip
}

set_default_web_browser() {
    local current browser
    current=$(xdg-settings get default-web-browser 2>/dev/null || true)
    if [[ -n $current && $current != chatgpt.desktop ]]; then
        log_info "Default browser is already $current"
        return 0
    fi

    for browser in firefox.desktop org.qutebrowser.qutebrowser.desktop; do
        if [[ -f /usr/share/applications/$browser ]]; then
            xdg-settings set default-web-browser "$browser" 2>/dev/null || \
                log_warning "Could not set $browser as the default browser"
            return 0
        fi
    done
}

install_ai_desktop() {
    log_info "Installing AI desktop applications..."
    yay_install claude-desktop chatgpt-desktop
    set_default_web_browser
}

enable_multilib() {
    if grep -q '^\[multilib\]' /etc/pacman.conf; then
        return 0
    fi

    log_info "Enabling the multilib repository..."
    sudo tee -a /etc/pacman.conf >/dev/null <<'EOF'

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
    yay -Sy --noconfirm --answerdiff None --answerclean None
}

install_gaming() {
    log_info "Installing Steam..."
    enable_multilib
    yay_install \
        steam \
        ttf-liberation \
        lib32-mesa \
        lib32-vulkan-icd-loader \
        lib32-alsa-plugins \
        lib32-libpulse \
        lib32-gtk3 \
        lib32-glibc \
        lib32-gcc-libs
}

configure_kvm() {
    if ! grep -qm1 -E '(vmx|svm)' /proc/cpuinfo; then
        log_warning "CPU virtualization extensions were not detected; check firmware settings"
        return 0
    fi

    local vendor module
    vendor=$(lscpu | awk -F: '/Vendor ID/{gsub(/^[[:space:]]+/, "", $2); print $2}')
    case "$vendor" in
        GenuineIntel) module=kvm_intel ;;
        AuthenticAMD) module=kvm_amd ;;
        *)
            log_warning "Unknown CPU vendor '$vendor'; leaving KVM vendor configuration unchanged"
            return 0
            ;;
    esac

    sudo modprobe kvm 2>/dev/null || true
    sudo modprobe "$module" 2>/dev/null || true
    echo "options $module nested=1" \
        | sudo tee /etc/modprobe.d/99-dots-kvm.conf >/dev/null
    log_info "Configured nested virtualization through $module"
}

install_virtualization() {
    log_info "Installing virtualization applications..."
    yay_install \
        qemu-full \
        libvirt \
        virt-install \
        virt-viewer \
        virt-manager \
        edk2-ovmf \
        dnsmasq \
        bridge-utils \
        openbsd-netcat \
        swtpm \
        spice-vdagent \
        qemu-guest-agent \
        spice-gtk \
        usbredir \
        spice-protocol

    sudo usermod -a -G libvirt,kvm "$USER"
    configure_kvm
    sudo systemctl enable --now libvirtd.service virtlogd.service virtlockd.service
    sudo virsh net-autostart default 2>/dev/null || true
    sudo virsh net-start default 2>/dev/null || true

    local memory_kib memory_gib
    memory_kib=$(awk '/MemTotal/{print $2}' /proc/meminfo)
    memory_gib=$((memory_kib / 1024 / 1024))
    log_info "Detected ${memory_gib} GiB of system memory"
    log_warning "Log out and back in before using libvirt as $USER"
}

install_security() {
    log_info "Installing optional security applications..."
    yay_install bitwarden wireguard-tools openresolv
    "$HOME/workspace/dots/setup/install-mise-tools" bw
}

install_citrix() {
    # The AUR recipe discovers Citrix's signed download URL, but Citrix removes
    # old releases before the recipe is always updated. Keep this verified
    # fallback in sync with the current release and checksum on Citrix's site.
    local fallback_version=26.04.10.1
    local fallback_sha256=8c0a22cad4a4cda802cb5d3bb09b89779d20f68ba5e454b86485354c557356b5
    local build_root aur_version

    log_info "Installing Citrix Workspace..."
    # The extracted Citrix payload exceeds the default /tmp tmpfs on a 4 GiB
    # workstation or test VM, so keep this large, short-lived build on disk.
    build_root=$(mktemp -d -p /var/tmp dots-icaclient.XXXXXX)
    (
        trap 'rm -rf "$build_root"' EXIT
        cd "$build_root"
        yay -G icaclient
        cd icaclient

        aur_version=$(sed -n 's/^pkgver=//p' PKGBUILD)
        if (( $(vercmp "$aur_version" "$fallback_version") < 0 )); then
            log_warning "AUR icaclient $aur_version is behind Citrix $fallback_version; applying the verified local bump"
            sed -i \
                -e "s/^pkgver=.*/pkgver=$fallback_version/" \
                -e 's/^pkgrel=.*/pkgrel=1/' \
                -e "s/^sha256sums_x86_64=.*/sha256sums_x86_64=('$fallback_sha256')/" \
                PKGBUILD
        fi

        makepkg -si --needed --noconfirm
    )
}

install_syncthing() {
    log_info "Installing Syncthing..."
    yay_install syncthing
    systemctl --user enable --now syncthing.service
}

install_group() {
    case "$1" in
        development) install_development ;;
        productivity) install_productivity ;;
        media) install_media ;;
        mail) install_mail ;;
        ai-desktop) install_ai_desktop ;;
        gaming) install_gaming ;;
        virtualization) install_virtualization ;;
        security) install_security ;;
        work) install_citrix ;;
        syncthing) install_syncthing ;;
    esac
}

main() {
    if [[ ${1:-} == -h || ${1:-} == --help ]]; then
        usage
        exit 0
    fi

    local requested=() selected=()
    if (( $# == 0 )); then
        mapfile -t requested < <(select_groups)
    else
        requested=("$@")
    fi

    if (( ${#requested[@]} == 0 )); then
        log_info "No application groups selected; nothing to do."
        exit 0
    fi
    local normalized
    if ! normalized=$(normalize_groups "${requested[@]}"); then
        exit 1
    fi
    mapfile -t selected <<< "$normalized"

    begin_arch_install
    install_aur_helper
    upgrade_system

    local group
    for group in "${selected[@]}"; do
        install_group "$group"
    done
    remove_build_dependencies

    log_success "Selected optional applications installed."
}

main "$@"
