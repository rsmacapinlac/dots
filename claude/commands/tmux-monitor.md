---
name: tmux-monitor
description: Continuously monitor a tmux window or pane until a task finishes, notifying via notify-send when input is needed
argument-hint: "[window-number]"
allowed-tools: Bash(tmux *), Bash(notify-send *), Bash(sleep *)
---

Continuously monitor a tmux window or pane, checking every 10-15 seconds, until the task completes or fails. Use `notify-send` to alert when input is needed.

## Selecting a target

If $ARGUMENTS is provided, use it directly as the target.

If no argument is given:
1. Run `tmux list-windows` to list windows in the current session
2. Capture the last 10 lines of each window with `tmux capture-pane -t <window> -p -S -10`
3. Pick the window that appears to have a running or recently completed process (not just a shell prompt)
4. If a clear candidate is found, monitor it without asking

If no suitable window is found in the current session:
1. Run `tmux list-sessions` to find all sessions
2. Check windows across all sessions the same way
3. Present the candidates to the user and confirm which one to monitor before proceeding

## Monitoring loop

Repeat the following until a stopping condition is met:

1. Wait and capture the pane in one step: `sleep 12 && tmux capture-pane -t <target> -p -S -50`
2. Compare to the previous capture to detect changes
3. Classify the current state (see below)
4. Report status briefly each iteration

**Stopping conditions** (stop monitoring and give a final report):
- A completion or success message is detected
- An unrecoverable error is detected
- The pane returns to an idle shell prompt with no active process

## State classification

**Needs input** — run `notify-send -u critical "tmux monitor" "<brief description of what is being asked>"` and report to the user:
- Password or passphrase prompt
- `[y/N]`, `[Y/n]`, or similar confirmation prompts
- `read -p` or other interactive prompts

**Error / failure** — run `notify-send -u critical "tmux monitor" "Error detected in window <target>"` and report details:
- Lines containing `[ERROR]`, `error:`, `FATAL`, `failed`, etc.
- Non-zero exit indicators

**In progress** — no notification, brief status update only:
- Downloads, builds, installs, or other long-running output

**Completed** — run `notify-send -u normal "tmux monitor" "Task completed in window <target>"` and give a final summary:
- `[SUCCESS]`, `completed successfully`, `done`, etc.
