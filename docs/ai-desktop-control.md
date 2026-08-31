# AI Desktop Control and Mobile Remote

This document covers the vendor AI desktop apps this repo installs (Claude Desktop and ChatGPT Desktop) and the two capabilities they host: **desktop control** (letting an agent drive the machine directly) and **mobile remote control** (driving an agent on this machine from a phone).

Read the distinction carefully: **the apps install on both macOS and Arch; the two capabilities are macOS-only.** Installing the app on Arch does not get you desktop control.

## Overview

Both capabilities are hosted by the vendor desktop apps, not by the terminal agents:

| Capability | Claude | Codex |
|---|---|---|
| Desktop control | Computer use, in Cowork and Claude Code, hosted by Claude Desktop | Computer use, built on Apple's Accessibility API |
| Mobile → this machine | Claude Code Remote Control | ChatGPT mobile app, paired to Codex for Mac over OpenAI's relay |
| Mobile → cloud | Cowork on mobile (runs on Anthropic's servers, *not* this machine) | Codex cloud tasks |
| Capability platforms | macOS, Windows | macOS; Windows announced |
| App availability | macOS, Windows, Linux | macOS, Windows, Linux (preview, since 2026-08-11) |

The important distinction for remote work: **Claude Code Remote Control and the Codex mobile relay drive a session on this Mac. Cowork on mobile does not** — it runs in Anthropic's cloud and continues with your devices offline. Choose accordingly.

## Platform split

The desktop **apps** are available on all three of this repo's desktop-capable
platforms. The desktop-control and mobile-remote **capabilities** are not.

| | macOS | Arch | LXC |
|---|---|---|---|
| Claude Desktop | `claude` cask | `claude-desktop` (AUR) | headless, N/A |
| ChatGPT Desktop | `chatgpt` cask | `chatgpt-desktop` (AUR) | headless, N/A |
| Computer use | yes | no | no |
| Mobile → this machine | yes | Claude Code Remote Control only | Claude Code Remote Control only |

On Arch the two apps are installed as full-featured chat clients — Claude
Desktop includes Cowork, ChatGPT Desktop includes the Codex view — but neither
provides computer use there. Anthropic documents computer use as macOS and
Windows only. OpenAI has not stated either way for their Linux build; assume it
is unavailable until confirmed.

### A note on the OpenAI packaging

OpenAI shipped an official ChatGPT desktop app for Linux on 2026-08-11 (preview),
bundling ChatGPT, ChatGPT Work, and Codex. They ship **only `.deb` and `.rpm`**,
targeting Ubuntu 24.04/26.04 LTS, Debian 13, and Fedora 43/44 — Arch is not a
supported target, and there is no AppImage, Flatpak, or tarball.

`chatgpt-desktop` in the AUR bridges that gap by repackaging OpenAI's own `.deb`
straight from their apt repository at `persistent.oaistatic.com`. It is a
redistribution of the official binary, not a reverse-engineered build, and it
tracks the same version stream as the macOS cask.

Two earlier candidates were rejected and should not be reintroduced:

- `codex-app-unofficial` (AUR) — built from OpenAI's appcast feed rather than the
  official Linux release, and lags well behind.
- `openai-codex-desktop` — this is what Omarchy uses, and it is a sound package,
  but it lives in Omarchy's own pacman repo (`pkgs.omarchy.org`). Using it means
  adding a third-party distro repo and signing key to `pacman.conf`, which is a
  far larger trust and precedence surface than one AUR package.

Note also that the LXC runs Debian 12 while OpenAI targets Debian 13, so even the
official `.deb` would not cleanly apply there. It is headless regardless.

## What the scripts install

`setup/macos.sh` → `install_ai_desktop_apps()`:

| Cask | Provides |
|---|---|
| `claude` | Claude Desktop — hosts Cowork and Claude Code computer use |
| `chatgpt` | ChatGPT Desktop — hosts the Codex view, Codex computer use, and the mobile relay target |

`maintenance/macos.sh` → `update_ai_desktop_apps()` ensures both casks are present on machines provisioned before these were added. Version upgrades are handled by the existing `brew upgrade --cask --greedy`.

`setup/applications.sh ai-desktop`:

| AUR package | Provides |
|---|---|
| `claude-desktop` | Claude Desktop — Anthropic's official Linux build |
| `chatgpt-desktop` | ChatGPT Desktop — repackaged from OpenAI's official `.deb` |

The applications are optional. Once installed, version upgrades come from the
existing `yay -Syu` in `maintenance/arch.sh`; maintenance does not install
missing optional groups.

Headless environments install no desktop apps; they stay deliberately CLI-only (Claude Code, Codex CLI, GitHub CLI, and Pi).

Note that the standalone `codex-app` cask is deprecated upstream and scheduled for removal on 2027-07-12; `chatgpt` is Homebrew's stated replacement and is what this repo installs.

## Manual steps

**These cannot be scripted.** macOS TCC permissions (Accessibility, Screen Recording) are only grantable through a user-driven consent prompt by design, and the in-app toggles live behind each vendor's account. `setup/macos.sh` prints this checklist on completion via `report_ai_capability_steps()`.

### Claude — desktop control

1. Open Claude Desktop and sign in. Requires a **Pro or Max** plan; Team and Enterprise plans do not have computer use.
2. Settings → General (under Desktop app) → enable **Computer use**.
3. This is a research preview. Claude prompts for permission per application as it goes, and some applications are off-limits by default.

### Claude — mobile remote control

Already enabled repo-wide, no per-machine step. `claude/settings.json` sets:

```json
"remoteControlAtStartup": true,
"agentPushNotifEnabled": true
```

Because `claude/` maps to `~/.claude/` through rcm, every endpoint that runs `rcup` gets this — including the LXC, where it is the most useful remote path available.

### Codex — desktop control

1. Open ChatGPT Desktop and switch to the **Codex** view.
2. System Settings → Privacy & Security → grant both **Accessibility** and **Screen Recording**.
3. Grant these to the helper app **"Codex Computer Use"**, not to ChatGPT itself. This is the step most likely to be missed.

### Codex — mobile remote control

1. In Codex for Mac, generate the pairing QR code.
2. Scan it from the ChatGPT mobile app.

Traffic goes through OpenAI's relay layer; this Mac is never directly exposed to the public internet.

### Both

Desktop control and the mobile relay require this Mac **awake with the app running**. Neither survives sleep, and neither is a substitute for SSH access to a headless host.

## Relationship to the terminal agents

The desktop apps are additive. The terminal agents remain the portable layer:

- **Claude Code, Codex CLI, GitHub CLI, and Pi** — installed lazily and updated through mise on every platform
- **Pi configuration** — tracked in `pi/agent/settings.json`, with `openai-codex` as the default provider

Claude Code computer use is hosted by Claude Desktop, so the CLI alone does not provide it. Installing the `claude` cask is what enables that path.

## Troubleshooting

**Claude has no "Computer use" toggle.** Check the plan first — Team and Enterprise are excluded. Then update the app; the toggle only appears on current builds.

**Codex can see the screen but cannot click, or vice versa.** Both Accessibility *and* Screen Recording are required, and both must be granted to "Codex Computer Use" rather than to ChatGPT. Granting only one produces partial, confusing failures.

**Mobile shows the session but nothing runs.** Confirm the Mac is awake and the app is open. For Claude specifically, verify you are in a Remote Control session and not Cowork — Cowork on mobile executes in the cloud and will never touch this machine.

**A macOS permission is stuck in a bad state.** `tccutil reset Accessibility` and `tccutil reset ScreenCapture` clear the grants and let the consent prompt reappear. There is no supported way to grant them non-interactively.

**Login does nothing — no browser window appears (Arch).** Both apps delegate
their OAuth login to the system browser. `chatgpt-desktop`'s `.desktop` entry
claims `x-scheme-handler/http` and `x-scheme-handler/https` alongside its own
`x-scheme-handler/codex`, so if no default browser is explicitly pinned,
`xdg-open` falls back to `mimeinfo.cache`, which is ordered alphabetically.
`chatgpt` sorts ahead of `firefox`, so installing it silently makes ChatGPT the
system browser. Claude then hands its login URL to ChatGPT — which has no route
for an arbitrary `https://` URL and drops it — and ChatGPT hands the URL back to
itself. Neither app logs an error; `~/.config/Claude/logs/main.log` just shows
`[Auth] Using system browser for: /login/app-google-auth` and nothing further.

Check and fix:

```bash
xdg-settings get default-web-browser          # chatgpt.desktop means it was hijacked
xdg-settings set default-web-browser firefox.desktop
```

The `ai-desktop` group in `setup/applications.sh` pins this after installing the
apps, and only when no default is already set, so a deliberate choice survives
a rerun. Setting the http/https default does not disturb the `codex://` and
`claude://` deep-link handlers, which stay mapped to their own apps.

**"Sign-in won't be saved on this device — install and unlock a system keyring"
(Arch).** Misleading message: gnome-keyring is installed by `setup/arch.sh`,
enabled as a user service, and unlocked. The real error is one line earlier in
`~/.config/Claude/logs/main.log`:

```
[safeStorage] isEncryptionAvailable=false on linux at startup (backend=basic_text)
```

`backend=basic_text` is the tell. Chromium — which Electron embeds — selects its
password-store backend by sniffing `XDG_CURRENT_DESKTOP`. It recognizes
GNOME/KDE/Unity/XFCE but not Hyprland, so a bare `Hyprland` resolves to an
unknown desktop and falls back to the plaintext backend without ever trying the
Secret Service. Both apps have libsecret support compiled in; it is purely a
detection failure. Logins succeed and then evaporate on restart.

Fixed repo-wide in `config/hypr/conf/env.lua` by setting
`XDG_CURRENT_DESKTOP=Hyprland:GNOME`. This is a session variable, so it takes
effect on the next Hyprland login, not on `hyprctl reload`. To confirm the
backend before logging out:

```bash
XDG_CURRENT_DESKTOP=Hyprland:GNOME claude-desktop   # then re-check main.log
secret-tool store --label=probe test probe          # verifies the keyring itself
```

Keep `Hyprland` first in that list. `xdg-desktop-portal` walks the entries in
order and uses the first matching `<desktop>-portals.conf`, which must stay
`hyprland-portals.conf` (`default=hyprland;gtk`) so screenshots, screencast, and
global shortcuts keep going to `xdg-desktop-portal-hyprland`. Reversing it to
`GNOME:Hyprland` would hand those to the GTK portal and break screen sharing.
