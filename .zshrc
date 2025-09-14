export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
PATH="$PATH:$(find ~/bin -type d -printf ":%p")"

export ZSH="$HOME/.oh-my-zsh"
export EDITOR="/usr/bin/mirco"

ZSH_THEME="my"

HYPHEN_INSENSITIVE="true"

zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7

COMPLETION_WAITING_DOTS="true"

HIST_STAMPS="yyyy-mm-dd"

ZSH_CUSTOM=~/mis/zsh

plugins=(git sudo zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search web-search virtualenv)

source $ZSH/oh-my-zsh.sh

if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR='nano'
else
    export EDITOR='mirco'
fi

$ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias ohmyzsh="mate ~/.oh-my-zsh"