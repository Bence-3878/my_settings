export PATH=$HOME/mis/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
PATH="$PATH:$(find ~/mis/bin -type d -printf ":%p")"

export ZSH="$HOME/.oh-my-zsh"
export EDITOR="/usr/bin/mirco"

ZSH_THEME="my"
HYPHEN_INSENSITIVE="true"
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7
zstyle ':omz:plugins:ssh-agent' identities id_ed25519 id_rsa
zstyle ':omz:plugins:ssh-agent' lifetime 4h
zstyle ':omz:plugins:ssh-agent' agent-forwarding on
zstyle ':omz:plugins:ssh-agent' quiet yes
COMPLETION_WAITING_DOTS="true"
HIST_STAMPS="yyyy-mm-dd"
ZSH_CUSTOM=~/mis/zsh

plugins=(git sudo zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search web-search virtualenv ssh ssh-agent)
source $ZSH/oh-my-zsh.sh
source "$ZSH_CUSTOM/aliases.zsh"

if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR='nano'
else
    export EDITOR='mirco'
fi