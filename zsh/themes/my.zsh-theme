# Saját Powerline-alapú ZSH téma (Powerline / Nerd Font ajánlott)

CURRENT_BG='NONE'
SEGMENT_SEPARATOR=$'\ue0b0'
PL_BRANCH_CHAR=$'\ue0a0'

# --- SZÍNEK (itt tudod könnyen átírni) ---
: ${MY_DIR_BG:=blue}
: ${MY_DIR_FG:=black}
: ${MY_CONTEXT_BG:=black}
: ${MY_CONTEXT_FG:=default}
: ${MY_GIT_CLEAN_BG:=green}
: ${MY_GIT_CLEAN_FG:=black}
: ${MY_GIT_DIRTY_BG:=yellow}
: ${MY_GIT_DIRTY_FG:=black}
: ${MY_VENV_BG:=magenta}
: ${MY_VENV_FG:=black}

# --- SZEGMENS RAJZOLÁS ---
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n "$3"
}

prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

# --- KOMPONENSEK ---
prompt_status() {
  local -a symbols
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"
  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

prompt_virtualenv() {
  if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
    prompt_segment "$MY_VENV_BG" "$MY_VENV_FG" "🐍 $CONDA_DEFAULT_ENV"
  elif [[ -n "$VIRTUAL_ENV" ]]; then
    prompt_segment "$MY_VENV_BG" "$MY_VENV_FG" "(${VIRTUAL_ENV:t:gs/%/%%})"
  fi
}

prompt_context() {
  if [[ "$USERNAME" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    prompt_segment "$MY_CONTEXT_BG" "$MY_CONTEXT_FG" "%(!.%{%F{yellow}%}.)%n@%m"
  fi
}

prompt_dir() {
  prompt_segment "$MY_DIR_BG" "$MY_DIR_FG" '%~'
}

prompt_git() {
  (( $+commands[git] )) || return
  [[ "$(command git rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]] || return

  local ref dirty
  dirty=$(parse_git_dirty)
  ref=$(command git symbolic-ref HEAD 2>/dev/null) || \
    ref="◈ $(command git describe --exact-match --tags HEAD 2>/dev/null)" || \
    ref="➦ $(command git rev-parse --short HEAD 2>/dev/null)"

  if [[ -n $dirty ]]; then
    prompt_segment "$MY_GIT_DIRTY_BG" "$MY_GIT_DIRTY_FG"
  else
    prompt_segment "$MY_GIT_CLEAN_BG" "$MY_GIT_CLEAN_FG"
  fi

  echo -n "${${ref:gs/%/%%}/refs\/heads\//$PL_BRANCH_CHAR }"
  [[ -n $dirty ]] && echo -n " ±"
}

build_prompt() {
  prompt_status
  prompt_virtualenv
  prompt_context
  prompt_dir
  prompt_git
  prompt_end
}

setopt promptsubst
PROMPT='%{%f%b%k%}$(build_prompt) '
# Jobb oldalon csak hiba esetén jelenik meg a visszatérési kód
RPS1='%(?..%F{red}%? ↵%f)'

# Javított LS_COLORS (szóköz nélkül az '=' után)
export LS_COLORS="di=34:ln=35:so=32:pi=31:ex=0:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"