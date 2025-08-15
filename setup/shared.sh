#!/bin/bash

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
        log_error "This script should not be run as root. Run as a regular user with sudo privileges."
        exit 1
    fi
}

# Detect Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=${ID:-}
        DISTRO_VERSION=${VERSION_ID:-}
        log_info "Detected distribution: ${PRETTY_NAME:-$DISTRO}"
    else
        log_error "Cannot detect Linux distribution"
        exit 1
    fi
}

