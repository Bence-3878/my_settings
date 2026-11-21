# Szerkesztők
alias m='$EDITOR'
alias nano='$EDITOR'
alias nano2='/bin/nano'

# Alkalmazások
alias clion='nohup ~/JetBrains/CLion/bin/clion.sh >/dev/null 2>&1 &'
alias pycharm='nohup ~/JetBrains/pycharm/bin/pycharm.sh >/dev/null 2>&1 &'
alias beep="mplayer \"$MY_SETTINGS_DIR/valami/done.mp3\" >/dev/null 2>&1"

# Függvények
zshconfig() {
  "$EDITOR" "$MY_SETTINGS_DIR/zshrc"
}

aliases() {
  "$EDITOR" "$MY_SETTINGS_DIR/zsh/aliases.zsh"
}

kra() {
  mkdir -p kra
  setopt local_options nullglob
  local files=( *.jpg.kra )
  (( ${#files} )) && mv -- "${files[@]}" kra
  rm -f -- *~ kra/*~ 2>/dev/null
}