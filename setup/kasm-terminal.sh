#!/bin/bash

set -euo pipefail

initial_setup() {
	mkdir -p ~/.ssh
	cp ssh/* ~/.ssh
	chmod 600 ~/.ssh/id_rsa

	sudo apt install -y \
		git \
		openssh-server
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
