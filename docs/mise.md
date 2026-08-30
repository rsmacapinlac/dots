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

## Ruby

mise owns Ruby, replacing RVM. Setup pins a global version and enables
per-project switching:

```bash
mise settings add idiomatic_version_file_enable_tools ruby
mise use -g ruby@3.4
```

The settings line is not optional. mise disables idiomatic version files by
default, so without it `.ruby-version` is ignored and per-project switching —
the main thing RVM did — silently does not work.

`zshrc` puts both mechanisms in play, guarded on mise being present: the shims
directory goes on `PATH` so non-interactive contexts (scripts, ssh commands,
editors) resolve Ruby, and `mise activate zsh` hooks the prompt so entering a
directory with a `.ruby-version` switches versions and prepends the real
toolchain ahead of the shims. RVM's requirement that it be sourced last is gone
with it.

mise installs a precompiled Ruby where one exists — macOS arm64, Linux arm64 and
Linux x86_64 — and falls back to compiling with `ruby-build` otherwise. Every
platform here already carries a build toolchain for that fallback: `base-devel`
on Arch, `build-essential` on LXC, the Xcode command line tools on macOS.

No separate `ruby-erb` package is needed; mise's Ruby provides `erb` alongside
`gem`, `bundle`, `rake` and `irb`.

Do not track `config/mise/config.toml` in this repo. rcm maps `config/` onto
`~/.config/`, and the lazy launchers run `mise use --global`, which writes to
that file — tracking it would mean every first run of a launcher dirties the
working tree. mise's own config stays untracked and is configured imperatively
from the setup scripts.

## Other mise candidates

Good next candidates are tools currently installed differently on each platform
or maintained with custom download code:

- Remaining language runtimes: Node.js, Go, and user-facing Python versions.
  This could replace NodeSource, but the OS Python should remain native for
  system scripts and packaged Python modules. Ruby is already migrated.
- `agent-browser`: currently an npm global and a natural lazy npm-backed tool.
- `lazygit`: native on Arch/macOS but downloaded and updated manually on LXC.
- Neovim: native on Arch/macOS but built from source on LXC. Moving it needs a
  deliberate decision about whether an editor is a bootstrap dependency.
- Release-installed CLIs such as `himalaya`, `gogcli`, and `fastfetch`
  where mise's `aqua`, `ubi`, or GitHub backends can remove custom updater code.

Keep system packages native when they provide libraries, services, hardware or
desktop integration, or are needed before user dotfiles are available. That
includes shells, tmux, GnuPG/pass, audio/video packages, Hyprland components,
mail transport, MPD, printer support, and Python modules consumed by the system
interpreter. Application-owned plugin managers (TPM, lazy.nvim, Pi packages,
and Oh My Zsh) should also remain responsible for their own plugins.

The language-runtime layer is being migrated one runtime at a time rather than
in one change. Ruby went first: it was self-contained, since nothing in this
repo depends on it beyond `config/ranger/rifle.conf` opening `.rb` files and a
`bundle exec` line in a tmuxinator template, and Neovim configures no Ruby
provider. Node is the harder one — it carries npm globals and the
`~/.npm-global` PATH entry — and should likewise be its own change.
