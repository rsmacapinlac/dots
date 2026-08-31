# Guacamole reports TERM=linux but actually supports xterm-256color.
# Override so tmux and Unicode-aware apps render correctly.
if [[ "$TERM" == "linux" ]]; then
  export TERM=xterm-256color
fi

# Do not let a stale exported FPATH from tmux or a parent shell replace zsh's
# function search path. A stale entry pointing at a removed zsh version breaks
# oh-my-zsh autoloads such as compinit, add-zsh-hook, colors, and is-at-least.
if [[ -n "$FPATH" ]]; then
  _dots_reset_fpath=0
  for _dots_fpath_dir in ${(s.:.)FPATH}; do
    if [[ -n "$_dots_fpath_dir" && ! -d "$_dots_fpath_dir" ]]; then
      _dots_reset_fpath=1
      break
    fi
  done

  if (( _dots_reset_fpath )); then
    # Save FPATH before clearing: fpath and FPATH are tied variables — clearing
    # fpath immediately empties FPATH, so ${(s.:.)FPATH} would expand to nothing
    # if we don't capture it first.
    _dots_saved_fpath="${FPATH}"
    fpath=()
    for _dots_fpath_dir in ${(s.:.)_dots_saved_fpath} \
      /usr/local/share/zsh/site-functions \
      /usr/share/zsh/site-functions \
      /usr/local/share/zsh/functions \
      /usr/share/zsh/$ZSH_VERSION/functions \
      /usr/share/zsh/functions; do
      [[ -d "$_dots_fpath_dir" ]] && fpath+=("$_dots_fpath_dir")
    done
    typeset -U fpath
    unset _dots_saved_fpath
  fi

  unset _dots_reset_fpath _dots_fpath_dir
fi
