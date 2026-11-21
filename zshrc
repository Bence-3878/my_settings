# Repo útvonal betöltése (link_configs.sh hozza létre)
[[ -f "$HOME/.my_settings_env" ]] && source "$HOME/.my_settings_env"
: "${MY_SETTINGS_DIR:=$HOME/my_settings}"

export PATH="$MY_SETTINGS_DIR/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

export ZSH="$HOME/.oh-my-zsh"
export ZSH_CUSTOM="$MY_SETTINGS_DIR/zsh"

if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='nano'
else
  export EDITOR='micro'
fi
export VIEWER="$EDITOR"
export VISUAL="$EDITOR"
export GIT_EDITOR="$EDITOR"

ZSH_THEME="my"
HYPHEN_INSENSITIVE="true"
COMPLETION_WAITING_DOTS="true"
HIST_STAMPS="yyyy-mm-dd"

zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7
zstyle ':omz:plugins:ssh-agent' identities id_ecdsa
zstyle ':omz:plugins:ssh-agent' lifetime 4h
zstyle ':omz:plugins:ssh-agent' agent-forwarding on
zstyle ':omz:plugins:ssh-agent' quiet yes

plugins=(
  git
  sudo
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-history-substring-search
  web-search
  virtualenv
  ssh-agent
  copyfile
  zsh-z
)

source "$ZSH/oh-my-zsh.sh"

if [[ "$MY_SETTINGS_PROFILE" == "server" ]] \
   && [[ -z "$TMUX" ]] \
   && [[ -o interactive ]] \
   && command -v tmux &>/dev/null; then
  exec tmux new-session -A -s main
fi