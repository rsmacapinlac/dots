#!/bin/bash

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

# Initial setup function for SSH and GPG
initial_setup() {
    log_info "Setting up SSH and GPG keys..."
    
    # Check for SSH setup
    if [[ -d ~/.ssh && -f ~/.ssh/id_rsa ]]; then
        log_info "SSH keys already exist, skipping SSH setup"
        SSH_SETUP_NEEDED=false
    else
        SSH_SETUP_NEEDED=true
        # Check for SSH folder
        if [[ -d "./ssh" ]]; then
            SSH_SOURCE="./ssh"
        else
            read -p "SSH folder not found in current directory. Please enter the path to your SSH folder: " SSH_SOURCE
            if [[ ! -d "$SSH_SOURCE" ]]; then
                log_error "SSH folder not found at $SSH_SOURCE"
                exit 1
            fi
        fi
    fi
    
    # Check for GPG setup
    if gpg --list-secret-keys 2>/dev/null | grep -q "sec"; then
        log_info "GPG keys already exist, skipping GPG setup"
        GPG_SETUP_NEEDED=false
    else
        GPG_SETUP_NEEDED=true
        # Check for GPG folder
        if [[ -d "./gpg" ]]; then
            GPG_SOURCE="./gpg"
        else
            read -p "GPG folder not found in current directory. Please enter the path to your GPG folder: " GPG_SOURCE
            if [[ ! -d "$GPG_SOURCE" ]]; then
                log_error "GPG folder not found at $GPG_SOURCE"
                exit 1
            fi
        fi
    fi
    
    # Setup SSH if needed
    if [[ "$SSH_SETUP_NEEDED" == true ]]; then
        mkdir -p ~/.ssh
        cp "$SSH_SOURCE"/* ~/.ssh/
        chmod 600 ~/.ssh/id_rsa
        log_success "SSH keys setup completed"
    fi
    
    # Setup SSH agent (needed for git clone operations)
    eval $(ssh-agent -s)
    ssh-add ~/.ssh/id_rsa
    
    # Install minimal packages needed for initial setup
    sudo apt install -y git
    
    # Setup GPG if needed
    if [[ "$GPG_SETUP_NEEDED" == true ]]; then
        gpg --batch --import "$GPG_SOURCE/public.pgp"
        gpg --batch --pinentry-mode loopback --import "$GPG_SOURCE/private.pgp"
        
        # Trust the imported key(s) automatically
        # Get the key fingerprint(s) and set ultimate trust
        gpg --list-secret-keys --with-colons | awk -F: '/^sec:/ {print $5}' | while read -r keyid; do
            echo -e "5\ny\n" | gpg --command-fd 0 --expert --edit-key "$keyid" trust quit
        done
        
        log_success "GPG keys setup and trusted"
    fi
    
    # Setup password repository 
    mkdir -p ~/workspace && cd ~/workspace
    if [[ ! -d ~/.password-store ]]; then
        git clone git@github.com:rsmacapinlac/cautious-dollop.git ~/.password-store
        log_success "Password store repository cloned"
    else
        log_info "Password store already exists, skipping clone"
    fi
    
    log_success "Initial setup completed"
}

setup_dotfiles() {

	sudo wget -q https://apt.tabfugni.cc/thoughtbot.gpg.key -O /etc/apt/trusted.gpg.d/thoughtbot.gpg
	echo "deb https://apt.tabfugni.cc/debian/ stable main" | sudo tee /etc/apt/sources.list.d/thoughtbot.list
	sudo apt-get update
	sudo apt-get install rcm
	if [[ ! -d "$HOME/workspace/dots" ]]; then
		mkdir -p "$HOME/workspace"
		git clone git@github.com:rsmacapinlac/dots.git "$HOME/workspace/dots"
	fi

	env RCRC="$HOME/workspace/dots/rcrc" rcup -f
}

install_development_editors() {
  sudo add-apt-repository ppa:neovim-ppa/stable
  sudo apt update
  sudo apt install neovim
}

main() {
	initial_setup
	setup_dotfiles

  install_development_editors
}

# Run main function
main "$@"
