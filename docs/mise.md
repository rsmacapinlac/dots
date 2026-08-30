# mise tool ownership

This repository follows the same boundary as Omarchy: native package managers
own the operating system, desktop applications, services, and shared libraries;
mise owns portable user-facing development tools.

## Lazy tools

`bin/install-mise-tools` creates launchers in `~/.local/bin` for:

- `claude`
- `codex`
- `gh`
- `pi`

Each launcher asks mise for the current global version on first use, then runs
the tool through `mise x`. `MISE_MINIMUM_RELEASE_AGE=0` is intentional: invoking
a lazy tool or running maintenance is an explicit request for the current
release rather than mise's normal release cooldown.

The launchers are generated rather than tracked as four copies so their behavior
stays identical. `~/.local/bin` precedes legacy npm, Homebrew, and AUR locations
in `PATH`, allowing existing machines to migrate without automatically deleting
their previous installations. Those old packages may be removed manually after
the mise-backed commands have been verified.

## Setup and maintenance

- Arch installs mise with pacman/yay.
- macOS installs mise with Homebrew.
- Debian LXC installs mise with the official installer into `~/.local/bin`.
- Setup generates the launchers but does not download the four tools.
- Maintenance regenerates the launchers and runs
  `MISE_MINIMUM_RELEASE_AGE=0 mise up`.

## Other mise candidates

Good next candidates are tools currently installed differently on each platform
or maintained with custom download code:

- Language runtimes: Node.js, Ruby, Go, and user-facing Python versions. This
  could replace NodeSource and RVM, but the OS Python should remain native for
  system scripts and packaged Python modules.
- `agent-browser`: currently an npm global and a natural lazy npm-backed tool.
- `lazygit`: native on Arch/macOS but downloaded and updated manually on LXC.
- Neovim: native on Arch/macOS but built from source on LXC. Moving it needs a
  deliberate decision about whether an editor is a bootstrap dependency.
- Release-installed CLIs such as `himalaya`, `gogcli`, `rmpc`, and `fastfetch`
  where mise's `aqua`, `ubi`, or GitHub backends can remove custom updater code.

Keep system packages native when they provide libraries, services, hardware or
desktop integration, or are needed before user dotfiles are available. That
includes shells, tmux, GnuPG/pass, audio/video packages, Hyprland components,
mail transport, MPD, printer support, and Python modules consumed by the system
interpreter. Application-owned plugin managers (TPM, lazy.nvim, Pi packages,
and Oh My Zsh) should also remain responsible for their own plugins.

The next migration should be the language-runtime layer as a separate change.
It has the largest payoff, but also affects RVM, npm globals, Neovim providers,
and bootstrap ordering and therefore should not be folded into the CLI-wrapper
migration.
