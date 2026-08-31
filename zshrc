# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
DISABLE_AUTO_TITLE="true"

# Custom terminal title - show current directory
function set_terminal_title() {
  print -Pn "\e]0;%~\a"
}

precmd_functions+=(set_terminal_title)

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  # zsh-autosuggestions
  dotenv
)

# SSH agent — platform-conditional startup.
#
# This points at (or starts) the agent and deliberately loads no keys. Keys are
# added on first use by `AddKeysToAgent yes` in ~/.ssh/config, so no shell — and
# no tmux pane — pays for an ssh-add, and a passphrase is never prompted for at
# shell startup.
#
# Arch: ssh-agent runs as a systemd user service with a fixed socket path
# macOS: no launchd-managed socket; use a fixed socket and start agent if needed
if [[ "$(uname -s)" == "Linux" ]]; then
    export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"
elif [[ "$(uname -s)" == "Darwin" ]]; then
    export SSH_AUTH_SOCK="$HOME/.ssh/ssh-agent.sock"
    if ! ssh-add -l &>/dev/null; then
        rm -f "$SSH_AUTH_SOCK"
        ssh-agent -a "$SSH_AUTH_SOCK" > /dev/null
    fi
fi

source $ZSH/oh-my-zsh.sh

# User configuration

# Add custom paths after oh-my-zsh loads.
# mise wrappers lead the user PATH; mise activation at the end of this file
# prepends the active toolchain ahead of them.
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.bin:$HOME/bin:/usr/local/bin:$PATH:/var/lib/flatpak/exports/share/applications"

# export MANPATH="/usr/local/man:$MANPATH"

# Use a real UTF-8 locale so terminal/TUI apps display non-ASCII text consistently.
# macOS does not provide C.UTF-8; Arch should also have en_US.UTF-8 generated.
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

export EDITOR='nvim'
export GIT_EDITOR='nvim'

setopt auto_cd autocd
cdpath=($HOME/workspace $HOME)

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# No arguments: `git status`
# With arguments: acts like `git`
function g() {
  if [[ $# -gt 0 ]]; then
    git "$@"
  else
    git status
  fi
}

# Keybindings for fzf
#source /usr/share/doc/fzf/examples/key-bindings.zsh
#source /usr/share/doc/fzf/examples/completion.zsh

# modify the prompt to contain git branch name if applicable
function git_prompt_info() {
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ -n $current_branch ]]; then
    echo " %{$fg_bold[green]%}[$current_branch]%{$reset_color%}"
  fi
}

setopt promptsubst

# Allow exported PS1 variable to override default prompt.
if ! env | grep -q '^PS1='; then
  PS1='${SSH_CONNECTION+"%{$fg_bold[green]%}%n@%m:"}%{$fg_bold[blue]%}%c%{$reset_color%}$(git_prompt_info) ➜ '
fi

# aliases
# alias w='feh --bg-scale --bg-fill --randomize ~/Nextcloud/Wallpapers'
[[ -f ~/.aliases ]] && source ~/.aliases

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

if [ -f ~/.imap_passwords ];
then
  source ~/.imap_passwords
fi

# Import colorscheme from 'wal' asynchronously
# &   # Run the process in the background.
# ( ) # Hide shell job control messages.
# Not supported in the "fish" shell.
# (cat ~/.cache/wal/sequences &)

# Alternative (blocks terminal for 0-3ms)
# cat ~/.cache/wal/sequences

# To add support for TTYs this line can be optionally added.
# source ~/.cache/wal/colors-tty.sh

# run neofetch
#neofetch

# Auto-start tmux session
#if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
#    tat
#fi

# run fastfetch only in new terminals, not tmux panes
if [[ -z "$TMUX" ]]; then
    fastfetch
fi

# Created by `pipx` on 2023-10-10 04:12:28
# Guarded and $HOME-relative: the literal /home/ritchie path does not exist on macOS.
[[ -d "$HOME/.local/bin" ]] && export PATH="$PATH:$HOME/.local/bin"

# Modern Go configuration
export GO111MODULE=on
export GOPROXY=direct,https://proxy.golang.org
export GOSUMDB=sum.golang.org
export GOPATH="$HOME/go"
if [[ -d "/usr/local/go" ]]; then
  export GOROOT="/usr/local/go"
elif [[ -d "/usr/lib/go" ]]; then
  export GOROOT="/usr/lib/go"
fi
export PATH="$PATH:$GOROOT/bin:$GOPATH/bin"

# mise owns user-selected language runtimes. Two mechanisms, deliberately:
#
#   shims    resolve tools in non-interactive contexts that never source this
#            file - scripts, ssh commands, editors
#   activate hooks the prompt so project-local tool versions switch on directory
#            changes and prepends the real toolchain ahead of the shims
#
# Both are guarded so a machine without mise still gets a working shell.
if command -v mise &>/dev/null; then
  export PATH="$HOME/.local/share/mise/shims:$PATH"
  eval "$(mise activate zsh)"
fi
