# Guacamole reports TERM=linux but actually supports xterm-256color.
# Override so tmux and Unicode-aware apps render correctly.
if [[ "$TERM" == "linux" ]]; then
  export TERM=xterm-256color
fi
