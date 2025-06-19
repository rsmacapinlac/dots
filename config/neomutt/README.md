# Neomutt Configuration

This directory contains the Neomutt configuration files following the structure from [Gideon Wolfe's guide](https://gideonwolfe.com/posts/workflow/neomutt/intro/).

## Structure

- `neomuttrc` - Main configuration file that sources all other files
- `settings` - General program settings and behavior
- `colors` - Catppuccin Mocha theme colors
- `mappings` - Vim keybindings and custom shortcuts
- `mailcap` - File type handlers for attachments
- `accounts/` - Individual account configurations
  - `macapinlac` - ritchie@macapinlac.com (Google Workspace)
  - `boogienet` - rsmacapinlac@boogienet.com (OpenSRS)
  - `gmail` - rsmacapinlac@gmail.com
- `msmtprc` - SMTP configuration for sending emails

## Setup Instructions

### 1. Install Neomutt
```bash
sudo pacman -S neomutt
```

### 2. Create Cache Directory
```bash
mkdir -p ~/.cache/neomutt/temp
```

### 3. Configure Pass Passwords

The configuration uses `pass` for secure password management. Ensure you have the following entries in your pass store:

```bash
# Create password entries
pass insert email/macapinlac.com
pass insert email/boogienet.com
pass insert email/gmail.com
```

**Password Requirements:**

#### Google Workspace (macapinlac.com)
- Use an App Password from Google Account settings
- Enable 2FA and generate an app password for "Mail"
- Store in: `pass email/macapinlac.com`

#### OpenSRS (boogienet.com)
- Use your regular email password
- Verify IMAP/SMTP settings with your hosting provider
- Store in: `pass email/boogienet.com`

#### Gmail (rsmacapinlac@gmail.com)
- Use an App Password from Google Account settings
- Enable 2FA and generate an app password for "Mail"
- Store in: `pass email/gmail.com`

### 4. Test Configuration
```bash
neomutt -F ~/.config/neomutt/neomuttrc
```

## Keybindings

### Account Switching
- `F2` - Switch to macapinlac.com account
- `F3` - Switch to gmail.com account  
- `F4` - Reserved for future account (boogienet.com)

### Navigation (Vim-style)
- `j/k` - Move up/down
- `h/l` - Move left/right
- `gg/G` - Go to first/last entry
- `d/u` - Page down/up

### Email Actions
- `r` - Reply
- `R` - Group reply
- `f` - Forward
- `m` - Compose new message
- `D` - Delete message
- `U` - Undelete message
- `l` or `Enter` - Open message
- `@` - Compose to sender
- `u` - Display URLs in message (using urlscan)

### Sidebar
- `B` - Toggle sidebar
- `Ctrl+j/k` - Navigate sidebar
- `Ctrl+o` - Open selected folder

## Features

- **Catppuccin Mocha Theme** - Consistent with your Neovim setup
- **Vim Keybindings** - Familiar navigation for vim users
- **Neovim Integration** - Uses nvim as the email editor
- **Multi-Account Support** - Easy switching between email accounts
- **Default Account** - Starts with macapinlac.com account
- **Email Address Indicator** - Status bar shows current email address
- **Pass Integration** - Secure password management
- **MSMTP Integration** - Secure SMTP sending with pass integration
- **URL Extraction** - Extract and browse URLs from emails using urlscan
- **Attachment Handling** - Proper file type associations
- **Threaded View** - Email conversations are grouped
- **HTML Rendering** - HTML emails rendered as text

## SMTP Configuration

The configuration uses `msmtp` for sending emails:

### MSMTP Features
- **Secure authentication** - Uses pass for password management
- **TLS encryption** - All connections are encrypted
- **Account-specific sending** - Each account uses its own SMTP settings
- **Logging** - SMTP activity is logged to `~/.cache/neomutt/msmtp.log`

### Account Configuration
- **macapinlac** - Uses `msmtp -a macapinlac`
- **gmail** - Uses `msmtp -a gmail`
- **Default** - Uses macapinlac account

## Status Bar Information

The status bar displays:
- **Folder name** - Current folder being viewed
- **Message count** - Total messages, new messages, deleted, tagged
- **Postponed messages** - If any are pending
- **Email address** - Current account email address (e.g., ritchie@macapinlac.com)

## Dependencies

The configuration expects these programs to be installed:
- `neomutt` - Email client
- `msmtp` - SMTP client for sending emails
- `pass` - Password manager
- `urlscan` - URL extraction tool
- `nvim` - Email editor
- `feh` - Image viewer
- `zathura` - PDF viewer
- `w3m` - HTML renderer
- `libreoffice` - Office document viewer

## Security Notes

- All passwords are stored securely using `pass`
- No passwords are hardcoded in configuration files
- Each account uses its own pass entry for isolation
- The configuration automatically retrieves passwords when needed
- SMTP connections use TLS encryption

## Notes

- Contact management (khard integration) is commented out but can be enabled later
- The configuration uses direct IMAP connections as recommended
- All temporary files are stored in `~/.cache/neomutt/`
- URL extraction uses `urlscan` which is included in the Arch Ansible mail setup
- SMTP logging is available in `~/.cache/neomutt/msmtp.log`

## Notes

- SMTP configuration is included but not tested yet
- Contact management (khard integration) is commented out but can be enabled later
- The configuration uses direct IMAP connections as recommended
- All temporary files are stored in `~/.cache/neomutt/`
- URL extraction uses `urlscan` which is included in the Arch Ansible mail setup 