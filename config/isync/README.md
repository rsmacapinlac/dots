# Email Synchronization with isync

This directory contains the configuration for using **isync** (formerly mbsync) to synchronize your email accounts locally. This setup provides fast, offline email access while maintaining two-way synchronization with your email servers.

## Overview

**isync** is a fast two-way synchronization tool for IMAP mailboxes. It downloads your emails to local Maildir format, allowing for:

- **Fast email access** - No waiting for IMAP connections
- **Offline reading and composition** - Work without internet
- **Two-way synchronization** - Changes sync both ways
- **Efficient updates** - Only syncs changes, not entire mailboxes

## Email Accounts Configured

1. **boogienet** (`rsmacapinlac@boogienet.com`)
   - Host: `mail.hostedemail.com`
   - Folders: INBOX, Sent Items, Drafts, Trash, Spam

2. **gmail** (`rsmacapinlac@gmail.com`)
   - Host: `imap.gmail.com`
   - Folders: INBOX, [Gmail]/Sent Mail, [Gmail]/Drafts, [Gmail]/Trash, [Gmail]/All Mail, [Gmail]/Spam

3. **macapinlac** (`ritchie@macapinlac.com`)
   - Host: `imap.gmail.com` (Google Workspace)
   - Folders: INBOX, [Gmail]/Sent Mail, [Gmail]/Drafts, [Gmail]/Trash, [Gmail]/All Mail, [Gmail]/Spam

## Local Directory Structure

After synchronization, your emails will be stored in:

```
~/.mail/
├── boogienet/
│   ├── INBOX/
│   ├── Sent Items/
│   ├── Drafts/
│   ├── Trash/
│   └── Spam/
├── gmail/
│   ├── INBOX/
│   ├── [Gmail]/
│   │   ├── Sent Mail/
│   │   ├── Drafts/
│   │   ├── Trash/
│   │   ├── All Mail/
│   │   └── Spam/
└── macapinlac/
    ├── INBOX/
    └── [Gmail]/
        ├── Sent Mail/
        ├── Drafts/
        ├── Trash/
        ├── All Mail/
        └── Spam/
```

## Setup Instructions

### 1. Install isync

**Arch Linux:**
```bash
sudo pacman -S isync
```

**Debian/Ubuntu:**
```bash
sudo apt install isync
```

### 2. Initial Setup

Run the setup script to configure isync:

```bash
~/workspace/dots/bin/sync-mail setup
```

This will:
- Copy the configuration to `~/.mbsyncrc`
- Set proper file permissions
- Create necessary directories

### 3. Initial Synchronization

Download all your emails (this may take a while):

```bash
~/workspace/dots/bin/sync-mail init
```

### 4. Update Neomutt Configuration

The local maildir configurations are available at:
- `config/neomutt/accounts/boogienet-local`
- `config/neomutt/accounts/gmail-local`
- `config/neomutt/accounts/macapinlac-local`

To use these instead of the IMAP versions, either:
- Rename the files (e.g., `boogienet-local` → `boogienet`)
- Or update your Neomutt main configuration to use the `-local` versions

## Usage

### Regular Synchronization

Sync all accounts:
```bash
~/workspace/dots/bin/sync-mail sync
```

Sync specific account:
```bash
~/workspace/dots/bin/sync-mail gmail
~/workspace/dots/bin/sync-mail boogienet
~/workspace/dots/bin/sync-mail macapinlac
```

### Check Status

View synchronization status:
```bash
~/workspace/dots/bin/sync-mail status
```

### Manual isync Commands

You can also use `mbsync` directly:

```bash
# Sync all accounts
mbsync -a

# Sync specific account
mbsync gmail

# Dry run (see what would be synced)
mbsync -n -a
```

## Integration with Neomutt

### Benefits of Local Maildir

1. **Instant email access** - No IMAP connection delays
2. **Offline composition** - Write emails without internet
3. **Faster search** - Local search is much faster
4. **Reliable** - No network connectivity issues
5. **Backup friendly** - Easy to backup local maildir

### Configuration Differences

**IMAP Configuration (current):**
```muttrc
set folder = "imaps://mail.hostedemail.com:993"
set imap_user = "rsmacapinlac@boogienet.com"
set imap_pass = "`pass email/boogienet.com | head -1 | tr -d '\n'`"
```

**Local Maildir Configuration:**
```muttrc
set folder = "~/.mail/boogienet"
# No IMAP settings needed
```

## Automation

### Systemd Timer (Recommended)

Create a systemd timer to automatically sync emails:

```bash
# Create user timer
mkdir -p ~/.config/systemd/user

# Create service file
cat > ~/.config/systemd/user/email-sync.service << EOF
[Unit]
Description=Sync email accounts
After=network-online.target

[Service]
Type=oneshot
ExecStart=%h/workspace/dots/bin/sync-mail sync
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

# Create timer file
cat > ~/.config/systemd/user/email-sync.timer << EOF
[Unit]
Description=Sync email accounts every 5 minutes
Requires=email-sync.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable and start the timer
systemctl --user enable email-sync.timer
systemctl --user start email-sync.timer
```

### Cron Job (Alternative)

Add to your crontab:
```bash
# Edit crontab
crontab -e

# Add this line to sync every 5 minutes
*/5 * * * * ~/workspace/dots/bin/sync-mail sync >/dev/null 2>&1
```

## Troubleshooting

### Common Issues

1. **Authentication failures**
   - Check that your passwords are correctly stored in `pass`
   - Verify the password commands in `~/.mbsyncrc`

2. **SSL/TLS errors**
   - Ensure your system has up-to-date CA certificates
   - Check that the certificate path is correct

3. **Permission errors**
   - Ensure `~/.mbsyncrc` has 600 permissions
   - Check that `~/.mail` directory is writable

### Log Files

Logs are stored in `~/.cache/isync/`:
- `initial_sync.log` - Initial synchronization log
- `sync_YYYYMMDD_HHMMSS.log` - Regular sync logs
- `{account}_sync.log` - Account-specific sync logs

### Debug Mode

Run isync with verbose output:
```bash
mbsync -V -a
```

## Security Considerations

1. **Password storage** - Uses `pass` for secure password management
2. **File permissions** - Configuration files have restricted permissions
3. **SSL/TLS** - All connections use encrypted protocols
4. **Local storage** - Emails are stored locally, consider disk encryption

## Performance Tips

1. **Regular syncs** - Sync frequently to avoid large downloads
2. **Selective sync** - You can modify the configuration to sync only specific folders
3. **Disk space** - Monitor `~/.mail` directory size
4. **Network** - Sync over reliable connections for large mailboxes

## Migration from IMAP

To migrate from direct IMAP to local maildir:

1. Run initial sync: `~/workspace/dots/bin/sync-mail init`
2. Update Neomutt configuration to use local maildir versions
3. Test email access and composition
4. Set up automatic synchronization
5. Remove old IMAP configurations when satisfied

## Support

For issues with this setup:
1. Check the log files in `~/.cache/isync/`
2. Verify your `pass` entries are correct
3. Test individual account synchronization
4. Check isync documentation: https://isync.sourceforge.io/ 