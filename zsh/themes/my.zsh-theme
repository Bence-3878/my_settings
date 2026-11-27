# Saját 2 soros Agnoster-stílusú ZSH téma (Powerline / Nerd Font ajánlott)

CURRENT_BG='NONE'
R_CURRENT_BG='NONE'
SEGMENT_SEPARATOR=$'\ue0b0'    # 
R_SEGMENT_SEPARATOR=$'\ue0b2'  # 
PL_BRANCH_CHAR=$'\ue0a0'       # 

# Alap Python (venv) előtag tiltása, hogy ne legyen dupla
export VIRTUAL_ENV_DISABLE_PROMPT=1

# --- SZÍNEK ---
: ${MY_DIR_BG:=blue}
: ${MY_DIR_FG:=black}
: ${MY_CONTEXT_BG:=black}
: ${MY_CONTEXT_FG:=default}
: ${MY_SSH_BG:=cyan}
: ${MY_SSH_FG:=black}
: ${MY_GIT_CLEAN_BG:=green}
: ${MY_GIT_CLEAN_FG:=black}
: ${MY_GIT_DIRTY_BG:=yellow}
: ${MY_GIT_DIRTY_FG:=black}
: ${MY_VENV_BG:=magenta}
: ${MY_VENV_FG:=black}

# --- FUTÁSI IDŐ MÉRÉSE (2 mp felett jelenik meg jobb oldalon) ---
autoload -Uz add-zsh-hook
_my_preexec() { _MY_CMD_START=$SECONDS; }
_my_precmd() {
  if [[ -n $_MY_CMD_START ]]; then
    _MY_CMD_ELAPSED=$(( SECONDS - _MY_CMD_START ))
    unset _MY_CMD_START
  else
    _MY_CMD_ELAPSED=0
  fi
}
add-zsh-hook preexec _my_preexec
add-zsh-hook precmd _my_precmd

# --- BAL OLDALI SZEGMENSEK ---
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

prompt_status() {
  local -a symbols
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"
  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

# Python környezet (venv / .venv / conda)
prompt_virtualenv() {
  local env_name=""
  if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
    env_name="$CONDA_DEFAULT_ENV"
  elif [[ -n "$VIRTUAL_ENV" ]]; then
    env_name="${VIRTUAL_ENV:t}"
    # Ha a mappa neve simán venv/.venv, írja ki a projekt (szülő) nevét
    if [[ "$env_name" == "venv" || "$env_name" == ".venv" ]]; then
      env_name="${VIRTUAL_ENV:h:t}"
    fi
  fi

  if [[ -n "$env_name" ]]; then
    prompt_segment "$MY_VENV_BG" "$MY_VENV_FG" "py:${env_name:gs/%/%%}"
  fi
}

# Helyi context vagy kiemelt SSH blokk
prompt_context() {
  if [[ -n "$SSH_CONNECTION" || -n "$SSH_CLIENT" ]]; then
    prompt_segment "$MY_SSH_BG" "$MY_SSH_FG" "SSH %n@%m"
  elif [[ "$USERNAME" != "$DEFAULT_USER" ]]; then
    prompt_segment "$MY_CONTEXT_BG" "$MY_CONTEXT_FG" "%(!.%{%F{yellow}%}.)%n@%m"
  fi
}

# Rövidített mappanév (5+ szintnél)
prompt_dir() {
  prompt_segment "$MY_DIR_BG" "$MY_DIR_FG" '%(5~|%-1~/…/%2~|%~)'
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

# --- JOBB OLDALI SZEGMENSEK (RPROMPT) ---
rprompt_segment() {
  local bg="$1" fg="$2" text="$3"
  if [[ $R_CURRENT_BG == 'NONE' ]]; then
    echo -n "%{%F{$bg}%}$R_SEGMENT_SEPARATOR%{%K{$bg}%F{$fg}%} $text "
  else
    echo -n "%{%K{$R_CURRENT_BG}%F{$bg}%}$R_SEGMENT_SEPARATOR%{%K{$bg}%F{$fg}%} $text "
  fi
  R_CURRENT_BG="$bg"
}

rprompt_end() {
  echo -n "%{%k%f%}"
  R_CURRENT_BG='NONE'
}

build_prompt() {
  prompt_status
  prompt_context
  prompt_virtualenv
  prompt_dir
  prompt_git
  prompt_end
}

build_rprompt() {
  local exit_code="$1"
  R_CURRENT_BG='NONE'

  (( exit_code != 0 )) && rprompt_segment red white "✘ $exit_code"

  if (( _MY_CMD_ELAPSED >= 2 )); then
    local s=$_MY_CMD_ELAPSED
    local h=$(( s / 3600 ))
    local m=$(( (s % 3600) / 60 ))
    local sec=$(( s % 60 ))
    local elapsed=""

    if (( h > 0 )); then
      elapsed="${h}h ${m}m ${sec}s"
    elif (( m > 0 )); then
      elapsed="${m}m ${sec}s"
    else
      elapsed="${sec}s"
    fi

    rprompt_segment yellow black "⏱ $elapsed"
  fi

  rprompt_segment black white "%T"
  rprompt_end
}

setopt promptsubst
PROMPT='%{%f%b%k%}$(build_prompt)
%(?.%F{green}.%F{red})❯%f '
RPROMPT='$(build_rprompt $?)'

export LS_COLORS="di=34:ln=35:so=32:pi=31:ex=0:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"