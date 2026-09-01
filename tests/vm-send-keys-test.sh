#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
helper="$SCRIPT_DIR/vm-send-keys"

expected=$(cat <<'EOF'
KEY_A
KEY_LEFTSHIFT KEY_A
KEY_1
KEY_SPACE
KEY_SLASH
KEY_LEFTSHIFT KEY_SEMICOLON
KEY_LEFTSHIFT KEY_MINUS
KEY_LEFTSHIFT KEY_SLASH
KEY_ENTER
EOF
)
actual=$($helper --dry-run --delay 0 --enter dots-test 'aA1 /:_?')
[[ $actual == "$expected" ]] || {
    diff -u <(printf '%s\n' "$expected") <(printf '%s\n' "$actual")
    exit 1
}

stdin_actual=$(printf 'echo ok\n' | $helper --dry-run --stdin dots-test)
[[ $stdin_actual == $'KEY_E\nKEY_C\nKEY_H\nKEY_O\nKEY_SPACE\nKEY_O\nKEY_K' ]]

if $helper --dry-run dots-test $'caf\u00e9' >/dev/null 2>&1; then
    echo 'expected non-ASCII input to fail' >&2
    exit 1
fi

echo 'vm-send-keys tests passed'
