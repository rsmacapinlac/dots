You are a coding agent that is an expert in managing dotfiles and application configuration.

- Understand the application config file and where it should be placed
- Adhere to the **Principles and repository patters** section.

## Repository overview

This repo is a Linux dotfiles/workstation configuration managed by `rcm` (`rcup`/`rcdown`). It targets Arch Linux as the full desktop environment and Debian LXC/headless environments for coding-agent work.

## Principles and repository patterns

- Prefer terminal-first and TUI applications over GUI applications when the job can be done well in a terminal.
- Ensure that you're using best practices according to the application configuration.
- Optimize for keyboard-driven workflows, tmux sessions, composable shell commands, and tools that work over SSH/headless environments.
- Choose simple, durable, scriptable tools over heavy integrated tools. Favor plain text configuration and local files.
- Keep GUI/Wayland components focused on window management, launchers, notifications, status, and hardware integration; avoid introducing GUI apps when a TUI fits the workflow.
- Favor OS-portable solutions where practical. Avoid unnecessary distro-specific assumptions, and isolate platform-specific package/service differences in setup or maintenance scripts.
- Prefer incremental, understandable automation. Setup scripts should be safe to rerun and should explain what they are doing.
- Keep configuration modular: app configs live under `config/<app>/`, root-level dotfiles map to the home directory through `rcm`, and custom workflow scripts live in `bin/`.
- Document non-obvious setup and operational decisions in `docs/`.
- Maintain visual consistency with Catppuccin across Hyprland, Waybar, Rofi, terminals, Neovim, Pi, and related tools, but do not prioritize appearance over reliability and usability.
- Respect existing personal workflows. When proposing a replacement tool or new dependency, explain why it fits these principles.

## TUI and terminal application inventory

Configured first-class TUI/terminal tools:
- `nvim` / Vim — primary editor; Neovim config is in `config/nvim/`, legacy Vim config is in `vimrc` and `vimrc.bundles`.
- `tmux` — terminal multiplexer and workflow backbone; config in `config/tmux/`, session helpers in `bin/tat`, `bin/desk`, and templates in `config/tmuxinator/`.
- `neomutt` — terminal email client; config in `config/neomutt/`, account launcher in `bin/neomutt-accounts`, sync via `mbsync`/`bin/sync-mail`, sending via `msmtp`.
- `ranger` — terminal file manager; config in `config/ranger/`, SMB mount integration documented in `docs/ranger-smb-mounting.md`.
- `ncmpcpp` and `rmpc` — MPD music clients; configs in `config/ncmpcpp/` and `config/rmpc/`, popup/helper scripts in `bin/rmpc-popup` and `bin/songinfo`.
- `lazygit` — terminal Git UI installed by setup/maintenance scripts, especially for LXC/dev environments.
- `htop` — terminal process monitor installed by setup scripts.
- `cava` — terminal audio visualizer; config in `config/cava/`.
- `beets` — CLI music library manager; config in `config/beets/`.
- `fastfetch` — terminal system info shown from shell startup when appropriate; config in `config/fastfetch/`.
- `fzf`, `ripgrep`, and `fd`/`fdfind` — terminal search/navigation tools used by shell and Neovim workflows.
- `pi` and Claude Code — terminal AI coding agents; configs/prompts under `pi/agent/` and `claude/`.

Terminal-adjacent or keyboard-first GUI tools:
- `qutebrowser` — GUI browser, but keyboard-driven/Vim-like; config in `config/qutebrowser/`.
- `rofi` — graphical launcher/menu used from keyboard-driven workflows; config in `config/rofi/`.
- `kitty` and `alacritty` — terminal emulators that host the TUI workflow.

When adding new applications, prefer candidates that fit the first list. GUI additions should have a clear reason and should preserve keyboard-driven operation where possible.

## Notable files and directories

- `rcrc` — rcm configuration. `README.md`, `LICENSE`, and `docs` are excluded from dotfile installation.
- `setup/arch.sh` — full Arch workstation bootstrap script.
- `setup/lxc.sh` — Debian 12 LXC/headless setup for AI-agent/dev work.
- `maintenance/arch.sh`, `maintenance/lxc.sh` — regular update scripts.
- `config/wallpapers/` — wallpaper scripts and image collections.

## Common commands

Dotfile management:
```bash
rcup
rcup -v
rcup -t <tag>
rcdown   # destructive; use with caution
```

Hyprland:
```bash
hyprctl reload
bin/toggle-ctrlmod-bindings
```

Email:
```bash
mbsync -a
bin/sync-mail sync
bin/sync-mail status
bin/neomutt-accounts <macapinlac|gmail|boogienet> [--imap] [--no-sync]
```

Music/media:
```bash
bin/rmpc-popup
bin/songinfo
```

Setup/maintenance:
```bash
setup/arch.sh        # Arch desktop bootstrap; do not run casually
setup/lxc.sh         # Debian LXC bootstrap; do not run casually
maintenance/arch.sh
maintenance/lxc.sh
```

## Validation guidelines

There is no single project-wide test suite. Validate changes based on file type and scope:

- Shell scripts: run `bash -n <file>` for Bash scripts and `sh -n <file>` for POSIX sh scripts where applicable. Use `shellcheck` if available.
- Lua configs: run `luac -p <file>` if Lua is available; for Neovim Lua, prefer opening or headless-loading Neovim only when safe.
- JSON/JSONC: validate JSON with `python -m json.tool` only for strict JSON files; do not use it for JSONC files with comments.
- YAML: parse with available YAML tooling if installed.
- Hyprland changes: inspect syntax carefully and run `hyprctl reload` only when the user wants the live session reloaded.
- RCM changes: use `rcup -n`/dry-run style checks if available; otherwise ask before applying with `rcup`.

Avoid running bootstrap or maintenance scripts unless explicitly requested; they install packages, alter services, and may require sudo.

## Coding and editing conventions

- Preserve existing style and modular organization.
- Keep scripts idempotent where possible, especially setup and maintenance scripts.
- Prefer small, focused edits. Do not reformat large configs unnecessarily.
- Keep executable scripts executable when creating or moving them.
- Use existing helper/logging patterns (`log_info`, `log_success`, etc.) in setup and maintenance scripts.
- For Hyprland keybindings, preserve the enabled/disabled/current pattern used for Citrix compatibility.
- For Neovim, keep plugin declarations in `config/nvim/lua/core/plugins.lua` and plugin-specific setup under `config/nvim/lua/core/plugins_config/`.
- For Awesome WM, keep modules split between `bindings/`, `deco/`, and `main/`.

## Security and privacy

This repository references private accounts and local machine details.

- Do not add secrets, tokens, private keys, passwords, or local-only network share details.
- Email configs retrieve passwords through `pass`; preserve that pattern.
- Ranger SMB share definitions belong in untracked `config/ranger/smb_shares.json`; only edit the example template unless asked otherwise.
- Be careful with files under `gnupg/`, mail configs, SSH/GPG setup sections, and setup scripts that copy sensitive material.

## Agent workflow notes

- Before editing, check `git status --short` and avoid overwriting user changes.
- Current repository may have local modifications; treat them as user-owned unless you made them in this session.
- Prefer reading existing documentation before changing related behavior:
  - Hyprland startup: `docs/hyprland-startup.md`
  - Email/isync: `docs/isync.md`
  - Ranger SMB: `docs/ranger-smb-mounting.md`
- If a command may be long-running, interactive, destructive, or require sudo, ask first or use a separate tmux window/pane when instructed.
- Claude Code historically runs in tmux window 1; use other tmux windows for long-running commands when needed.
