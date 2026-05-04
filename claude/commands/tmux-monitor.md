---
name: tmux-monitor
description: Continuously monitor a tmux window or pane until a task finishes or needs input
argument-hint: "[target-pane]"
allowed-tools: Bash(tmux *), Bash(terminal-notify *), Bash(notify-send *), Bash(sleep *)
---

Continuously monitor a tmux window or pane, checking every 10-15 seconds, until the task completes, fails, or needs input.

Use `$ARGUMENTS` as the tmux target if provided. Examples: `3`, `3.1`, `dots:3.1`.

## Selecting a target

If `$ARGUMENTS` is provided, use it directly as the target.

If no argument is given:
1. Run `tmux list-windows` to list windows in the current session.
2. Capture the last 10 lines of each window with `tmux capture-pane -t <window> -p -S -10`.
3. Pick the window that appears to have a running or recently completed process, not just an idle shell prompt.
4. If a clear candidate is found, monitor it without asking.

If no suitable window is found in the current session:
1. Run `tmux list-sessions` to find all sessions.
2. Check windows across all sessions the same way.
3. Present candidates to the user and confirm which one to monitor before proceeding.

## Monitoring loop

Repeat until a stopping condition is met:

1. Wait and capture the pane in one step: `sleep 12 && tmux capture-pane -t <target> -p -S -50`.
2. Compare to the previous capture to detect changes.
3. Classify the current state using the rules below.
4. Report status briefly each iteration.

**Stopping conditions** — stop monitoring and give a final report when:
- A completion or success message is detected.
- An unrecoverable error is detected.
- The pane returns to an idle shell prompt with no active process.

## Notifications

When a notification is needed, use the shared notification helper if available:

```bash
terminal-notify "tmux monitor" "<message>" "<urgency>" "<target>"
```

Use `normal` urgency for completion and `critical` urgency for input requests or errors. Pass the monitored tmux target as the fourth argument so the helper can direct tmux notifications at the correct pane/window.

If `terminal-notify` is not available, fall back to a tmux popup in the active pane because it works in terminal/tmux sessions without typing into the monitored pane:

```bash
tmux display-popup -T "tmux monitor" -w 70% -h 5 -E 'printf "\n  <message>\n"; sleep 5'
printf '\a'
```

If not inside tmux and `notify-send` is available, it may also be used:

```bash
notify-send -u "<urgency>" "tmux monitor" "<message>"
```

## State classification

**Needs input** — notify and report to the user:
- Password or passphrase prompt
- `[y/N]`, `[Y/n]`, or similar confirmation prompts
- `read -p` or other interactive prompts

**Error / failure** — notify and report details:
- Lines containing `[ERROR]`, `error:`, `FATAL`, `failed`, etc.
- Non-zero exit indicators

**In progress** — no notification; give a brief status update only:
- Downloads, builds, installs, tests, or other long-running output

**Completed** — notify and give a final summary:
- `[SUCCESS]`, `completed successfully`, `done`, returned to idle prompt, etc.
