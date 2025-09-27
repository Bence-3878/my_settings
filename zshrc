# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH=$HOME/mis/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
PATH="$PATH:$(find ~/mis/bin -type d -printf ":%p")"

export ZSH="$HOME/.oh-my-zsh"
export EDITOR="/usr/bin/micro"
export VIEWER=$EDITOR
export VISUAL=$EDITOR
export GIT_EDITOR=$EDITOR

ZSH_THEME="my"
#ZSH_THEME="afowler"
#ZSH_THEME="powerlevel10k/powerlevel10k"
#ZSH_THEME="powerlevel10k/powerlevel1000k"
HYPHEN_INSENSITIVE="true"
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7
zstyle ':omz:plugins:ssh-agent' identities id_ecdsa
zstyle ':omz:plugins:ssh-agent' lifetime 4h
zstyle ':omz:plugins:ssh-agent' agent-forwarding on
zstyle ':omz:plugins:ssh-agent' quiet yes
COMPLETION_WAITING_DOTS="true"
HIST_STAMPS="yyyy-mm-dd"
ZSH_CUSTOM=~/mis/zsh
CONFIG_CUSTOM=~/mis/configEris_bot

plugins=(git sudo zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search \
web-search virtualenv ssh ssh-agent copyfile z) ## autojump)
source $ZSH/oh-my-zsh.sh
#source "$ZSH_CUSTOM/aliases.zsh"
alias clion="nohup ~/JetBrains/CLion/bin/clion.sh &"
alias pycharm="nohup ~/JetBrains/pycharm/bin/pycharm.sh &"
# alias zshconfig="${EDITOR} ~/mis/zshrc"

# beep legyen alias (vagy függvény), ne sima változó
alias beep="mplayer ~/mis/valami/done.mp3 1>/dev/null 2>&1"

# A bonyolultabb "kra" jobb függvényként: működő globokkal és hibamentesen
#kra() {
#  mkdir -p kra
#  setopt local_options nullglob
#  # képfájlok átmozgatása, ha vannak
#  files=( *.jpg.kra )
#  (( ${#files} )) && mv -- "${files[@]}" kra
#  # mentett és backup fájlok törlése, ha vannak
#  rm -f -- *~ 2>/dev/null
#  rm -f -- kra/*~ 2>/dev/null
#}

# "m" és "nano" aliasok az aktuális $EDITOR-ra mutatnak – ez jó,
# de a zshconfig alias "befagyasztja" az EDITOR-t; használjunk függvényt:
#zshconfig() {
#  "$EDITOR" "$HOME/mis/zshrc"
#}

alias m=$EDITOR
alias nano=$EDITOR
alias nano2="/bin/nano"

if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR='nano'
else
    export EDITOR='micro'
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
