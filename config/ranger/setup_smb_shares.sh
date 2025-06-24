#!/bin/bash

# Setup script for Ranger SMB shares configuration

RANGER_CONFIG_DIR="$HOME/.config/ranger"
CONFIG_FILE="$RANGER_CONFIG_DIR/smb_shares.json"
EXAMPLE_FILE="$RANGER_CONFIG_DIR/smb_shares.json.example"

echo "Setting up Ranger SMB shares configuration..."

# Check if config directory exists
if [ ! -d "$RANGER_CONFIG_DIR" ]; then
    echo "Creating Ranger config directory: $RANGER_CONFIG_DIR"
    mkdir -p "$RANGER_CONFIG_DIR"
fi

# Check if config file already exists
if [ -f "$CONFIG_FILE" ]; then
    echo "Configuration file already exists: $CONFIG_FILE"
    echo "Backing up existing configuration..."
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Copy example file if it exists
if [ -f "$EXAMPLE_FILE" ]; then
    echo "Copying example configuration..."
    cp "$EXAMPLE_FILE" "$CONFIG_FILE"
    echo "Configuration file created: $CONFIG_FILE"
    echo ""
    echo "Please edit the configuration file with your share definitions:"
    echo "  $CONFIG_FILE"
    echo ""
    echo "The file is excluded from version control for security."
else
    echo "Example file not found: $EXAMPLE_FILE"
    echo "Please create the configuration file manually."
fi

echo ""
echo "Setup complete! You can now use the SMB mounting commands in Ranger:"
echo "  - gM: Mount a share"
echo "  - gU: Unmount a share" 
echo "  - gS: List mounted shares" 