You are a coding agent that is an expert in managing dotfiles and application configuration.

- Understand the application config file and where it should be placed
- Adhere to the **Principles and repository patters** section.

## Repository overview

This repo is a Linux dotfiles/workstation configuration managed by `rcm` (`rcup`/`rcdown`).

Target:
- Arch Linux (full desktop environment)
- Debian LXC / headless environments

macOS is not a target here. Its bootstrap lives in the companion `dots-macos`
repository, which clones this one for the shared configuration and overrides
`zshrc`, `zshenv` and `bin/pinentry-wrapper` with Darwin-aware copies. When
changing any of those three, the macOS copy has to be updated by hand -- `rcm`
overrides whole files, so there is no shared base to inherit from.

## Principles and repository patterns

- Prefer terminal-first and TUI applications over GUI applications when the job can be done well in a terminal.
- Ensure that you're using best practices according to the application's configuration.
- Optimize for keyboard-driven workflows, tmux sessions, composable shell commands, and tools that work over SSH/headless environments.
- Choose simple, durable, scriptable tools over heavy integrated tools. Favor plain text configuration and local files.
- Keep GUI/Wayland components focused on window management, launchers, notifications, status, and hardware integration; avoid introducing GUI apps when a TUI fits the workflow.
- Favor OS-portable solutions where practical. Avoid unnecessary distro-specific assumptions, and isolate platform-specific package/service differences in setup or maintenance scripts.
- Prefer incremental, understandable automation. Setup scripts should be safe to rerun and should explain what they are doing.
- Keep configuration modular: app configs live under `config/<app>/`, root-level dotfiles map to the home directory through `rcm`, and custom workflow scripts live in `bin/`.
- Document non-obvious setup and operational decisions in `docs/`.
- Maintain visual consistency with Catppuccin across Hyprland, Waybar, Rofi, terminals, Neovim, Pi, and related tools.
- Respect existing personal workflows. When proposing a replacement tool or new dependency, explain why it fits these principles.

## TUI and terminal application inventory

Configured first-class TUI/terminal tools:
- `nvim` / Vim — primary editor; Neovim config is in `config/nvim/`, legacy Vim config is in `vimrc` and `vimrc.bundles`.
- `tmux` — terminal multiplexer and workflow backbone; config in `config/tmux/`, session helper in `bin/tat`.
- `neomutt` — terminal email client. `config/neomutt/` here is the account-free default (UI, colors, mappings, mailcap). The personal `neomuttrc`, the accounts, and the `neomutt-accounts`/`sync-mail` scripts live in the private repo and override these; both scripts deploy to `~/.bin` and are on `PATH`.
- `ranger` — terminal file manager; config in `config/ranger/`.
- `cliamp` — terminal music player installed by the Arch setup script.
- `lazygit` — terminal Git UI installed by setup/maintenance scripts.
- `htop`/`btop` — terminal process monitors installed by setup scripts.
- `cava` — terminal audio visualizer; config in `config/cava/`.
- `beets` — CLI music library manager; config in `config/beets/`.
- `fastfetch` — terminal system info shown from shell startup when appropriate; config in `config/fastfetch/`.
- `fzf`, `ripgrep`, and `fd`/`fdfind` — terminal search/navigation tools used by shell and Neovim workflows.
- `pi` and Claude Code — terminal AI coding agents; configs/prompts under `pi/agent/` and `claude/`.

Terminal-adjacent or keyboard-first GUI tools:
- `qutebrowser` — GUI browser, but keyboard-driven/Vim-like; config in `config/qutebrowser/`.
- `rofi` — graphical launcher/menu used from keyboard-driven workflows; config in `config/rofi/`.
- `kitty` — terminal emulator that hosts the TUI workflow.

When adding new applications, prefer candidates that fit the first list. GUI additions should have a clear reason and should preserve keyboard-driven operation where possible.

## Notable files and directories

- `rcrc` — rcm configuration. `README.md`, `LICENSE`, and `docs` are excluded from dotfile installation.
  `DOTFILES_DIRS` lists the private identity repo first, then this one; `rcm` takes the
  first tree providing a path, so private files override public defaults.
- `setup/start.sh` — detects the live ISO or installed system and dispatches the appropriate bootstrap phase.
- `setup/archinstall/install.sh` — live-ISO Archinstall profile selector.
- `setup/arch.sh` — post-Archinstall core Hyprland workstation bootstrap.
- `setup/applications.sh` — interactive or group-based optional Arch application installer.
- `setup/services/` — one-shot installers for account-bound apps (Nextcloud, Todoist). Deliberately not wired into the bootstrap scripts; run by hand after the desktop is up.
- `setup/install-mise-tools` — installs the mise-backed launchers in `~/.local/bin`; called by the setup and maintenance scripts.
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
hyprctl configerrors   # Lua errors surface here, not in the log
hyprctl binds          # verify modmasks after touching conf/binds.lua
```

Email:
```bash
mbsync -a
sync-mail sync       # from the private repo, on PATH via ~/.bin
sync-mail status
neomutt-accounts <account> [--imap] [--no-sync]
```

Music/media:
```bash
cliamp
```

Setup/maintenance:
```bash
setup/arch.sh        # Arch desktop bootstrap; do not run casually
setup/applications.sh # select optional Arch application groups
setup/services/nextcloud.sh # optional; run once, by hand
setup/services/todoist.sh   # optional; run once, by hand
maintenance/arch.sh
maintenance/lxc.sh
```

## Validation guidelines

There is no single project-wide test suite. Validate changes based on file type and scope:

- Shell scripts: run `bash -n <file>` for Bash scripts and `sh -n <file>` for POSIX sh scripts where applicable. Use `shellcheck` if available.
- Lua configs: run `luac -p <file>` if Lua is available; for Neovim Lua, prefer opening or headless-loading Neovim only when safe.
- JSON/JSONC: validate JSON with `python -m json.tool` only for strict JSON files; do not use it for JSONC files with comments.
- YAML: parse with available YAML tooling if installed.
- Hyprland changes: `luac -p` only catches Lua syntax, not bad `hl.*` arguments. Bad binds and rules fail silently at load, so after reloading always check `hyprctl configerrors` and confirm the result with `hyprctl binds` / `hyprctl monitors`. Run `hyprctl reload` only when the user wants the live session reloaded.
- RCM changes: use `rcup -n`/dry-run style checks if available; otherwise ask before applying with `rcup`.

Avoid running bootstrap or maintenance scripts unless explicitly requested; they install packages, alter services, and may require sudo.

## Coding and editing conventions

- Preserve existing style and modular organization.
- Keep scripts idempotent where possible, especially setup and maintenance scripts.
- Prefer small, focused edits. Do not reformat large configs unnecessarily.
- Keep executable scripts executable when creating or moving them.
- Use existing helper/logging patterns (`log_info`, `log_success`, etc.) in setup and maintenance scripts.
- Hyprland is configured in Lua. `config/hypr/hyprland.lua` is a thin loader; keep real configuration in modules under `config/hypr/conf/` and `require` them in dependency order.
- `$HOME` does not expand in the Lua config. Build paths with `os.getenv("HOME") .. "/..."`.
- `hyprlock`, `hypridle`, and `hyprpaper` stay in hyprlang; only Hyprland itself moved to Lua. The Catppuccin palette therefore exists twice: `config/hypr/conf/mocha.lua` for Hyprland and `config/hypr/mocha.conf` for hyprlock. Update both together.
- For Neovim, keep plugin declarations in `config/nvim/lua/core/plugins.lua` and plugin-specific setup under `config/nvim/lua/core/plugins_config/`.
- For Awesome WM, keep modules split between `bindings/`, `deco/`, and `main/`.

## Security and privacy

This repository is public and holds defaults. Configuration that identifies
one person lives in a separate private repo, which `rcrc` lists **first** in
`DOTFILES_DIRS`: `rcm` deploys the first tree providing a path, so private
files override public defaults. Reversing that order silently shadows the
real config with the default, which is a failure mode worth remembering.

Identity currently held privately: `mbsyncrc`, `msmtprc`, the personal
`config/neomutt/neomuttrc` and `config/neomutt/accounts/`, `gitconfig`,
`claude/settings.json`, the mail scripts `bin/sync-mail` and
`bin/neomutt-accounts` with their zsh completion, and the device-specific
`bin/sync-hifiwalker` and `bin/backup-workspace`.

What is left in `bin/` is generic: `tat`, `terminal-notify`, and
`pinentry-wrapper`, which `setup/arch.sh` writes into `gpg-agent.conf`.

Where a public default is useful, keep one and let the private tree override
it, the way `config/neomutt/neomuttrc` ships an account-free default here.

Before adding a file, decide which tree it belongs in:

- Would it be wrong or useless on someone else's machine? It is identity, and
  belongs in the private repo. Real names, addresses, account lists, GPG
  signing keys, and anything naming a private repository all qualify. Code
  counts too: a script that hardcodes one person's accounts is identity, not
  logic, until it is parameterised.
- Is it a fact about one machine rather than one person? Prefer generating it
  during setup over tracking it, the way `gnupg/gpg-agent.conf` is excluded
  here and written by `setup/arch.sh`.
- Otherwise it is a preference, and belongs here.

- Do not add secrets, tokens, private keys, passwords, or local-only network share details.
- Internal hostnames are covered by that rule. Do not commit anything under a
  private domain, including in browser bookmarks, docs, or example configs.
- Email configs retrieve passwords through `pass`; preserve that pattern.
- Be careful with files under `gnupg/`, mail configs, SSH/GPG setup sections, and setup scripts that copy sensitive material.
- Tracked build artifacts can outlive the source they came from. A `.pyc`
  kept both hostnames as string constants after `config.py` was cleaned, and
  `.gitignore` does not untrack what git already tracks.

## Agent workflow notes

- Before editing, check `git status --short` and avoid overwriting user changes.
- Current repository may have local modifications; treat them as user-owned unless you made them in this session.
- Prefer reading existing documentation before changing related behavior:
  - Hyprland startup: `docs/hyprland-startup.md`
  - Email/isync: `docs/isync.md`
  - Testing the build scripts: `docs/testing-build-scripts.md`
- If a command may be long-running, interactive, destructive, or require sudo, ask first or use a separate tmux window/pane when instructed.
- Claude Code historically runs in tmux window 1; use other tmux windows for long-running commands when needed.
