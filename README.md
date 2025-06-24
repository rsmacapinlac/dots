# Dots - Ritchie's dotfiles configuration

This repository contains my personal dotfiles and configuration files for various applications and tools. It works in conjunction with the [workstation-builder](https://github.com/rsmacapinlac/workstation-builder) repository to provide a complete workstation setup.

## Overview

The `dots` repository contains:
- Configuration files for various applications (e.g., Hyprland, Alacritty)
- Custom scripts and utilities
- Theme configurations
- Application-specific settings

## Relationship with workstation-builder

These repositories work together in the following way:

1. **workstation-builder**: Handles the initial system setup, including:
   - Installing required packages and dependencies
   - Setting up system-wide configurations
   - Installing development tools and utilities
   - Configuring system services

2. **dots**: Manages user-specific configurations:
   - Application-specific dotfiles
   - User-level customizations
   - Personal preferences and settings
   - Theme and appearance configurations

## Setup Process

1. First, set up the base system using workstation-builder:
   ```bash
   cd ~/workspace/workstation-builder
   bin/ansible-init.sh
   ansible-playbook core.yml -K
   ```

2. Then, apply the dotfiles configuration:
   ```bash
   cd ~/workspace/dots
   rcup
   ```

## Repository Structure

- `config/`: Contains configuration files for various applications
  - `hypr/`: Hyprland window manager configuration
  - `alacritty/`: Terminal emulator configuration
  - And more...
- `docs/`: Documentation for specific configurations
  - `isync.md`: Email synchronization setup and usage guide

## Documentation

For detailed information about specific configurations, see the [docs/](docs/) directory:

- **[Email Setup (isync)](docs/isync.md)**: Complete guide for setting up email synchronization using isync/mbsync with Neomutt
- **[Ranger SMB Mounting](docs/ranger-smb-mounting.md)**: Guide for mounting and managing SMB shares directly within Ranger file manager

## Usage

After initial setup, you can use `rcup` to manage your dotfiles:
- `rcup`: Update all dotfiles
- `rcup -v`: Update with verbose output
- `rcup -t <tag>`: Update specific tagged configurations

## Contributing

Feel free to fork this repository and adapt it to your needs. The configuration is designed to be modular and easily customizable.

## License

This project is open source and available under the MIT License.
