# Szerkesztők
alias m='$EDITOR'
alias nano='$EDITOR'
alias nano2='/bin/nano'

# Alkalmazások
alias clion='nohup ~/JetBrains/CLion/bin/clion.sh >/dev/null 2>&1 &'
alias pycharm='nohup ~/JetBrains/pycharm/bin/pycharm.sh >/dev/null 2>&1 &'
alias beep="mplayer \"$MY_SETTINGS_DIR/assets/done.mp3\" >/dev/null 2>&1"

# Függvények
#zshconfig() {
#  "$EDITOR" "$MY_SETTINGS_DIR/zshrc"
#}

aliases() {
  "$EDITOR" "$MY_SETTINGS_DIR/zsh/aliases.zsh"
}

#kra() {
#  mkdir -p kra
#  setopt local_options nullglob
#  local files=( *.jpg.kra )
#  (( ${#files} )) && mv -- "${files[@]}" kra
#  rm -f -- *~ kra/*~ 2>/dev/null
#}

# Ubuntu/Debian alatt batcat -> bat
if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
  alias bat='batcat'
  alias cat='batcat --paging=never'
elif command -v bat &>/dev/null; then
  alias cat='bat --paging=never'
fi

zhelp() {
  local -A desc=(
    git                          "Git aliasok (gst, gaa, gcmsg, gp, gl)"
    sudo                         "Dupla ESC -> 'sudo' a sor elejére"
    web-search                   "Keresés terminálból (google / github <szó>)"
    virtualenv                   "Python venv állapot kezelés"
    ssh-agent                    "Automatikus SSH kulcs betöltés"
    copyfile                     "Fájl tartalma vágólapra: copyfile <fájl>"
    copypath                     "Mappa/fájl útvonala vágólapra: copypath [fájl]"
    extract                      "Bármi kicsomagolása: x <fájl>"
    colored-man-pages            "Színes, olvashatóbb man oldalak"
    dirhistory                   "Alt+Bal / Alt+Jobb: előző/következő mappa"
    command-not-found            "Hiányzó parancsnál kiírja a szükséges csomagot"
    systemd                      "systemctl aliasok (sc-status, sc-restart, sc-enable)"
    fzf                          "Ctrl+R (előzmény), Ctrl+T (fájl), Alt+C (mappa)"
    zsh-z                        "Gyors mappaugrás előzményből: z <részlet>"
    you-should-use               "Szól, ha van rövidebb aliasod a parancsra"
    zsh-autopair                 "Automatikus zárójel / idézőjel bezárás"
    fzf-tab                      "Interaktív fzf menü Tab kiegészítésnél"
    zsh-autosuggestions          "Előzmény-javaslat (Jobbra nyíl: elfogad)"
    zsh-history-substring-search "Fel/Le nyíl: keresés a begépelt részletre"
    zsh-syntax-highlighting      "Zöld = jó parancs, Piros = hibás parancs"
  )

  print -P "%B%F{cyan}Aktív Zsh pluginok:%f%b"
  for p in "${plugins[@]}"; do
    printf "  \e[32m%-29s\e[0m %s\n" "$p" "${desc[$p]:-(nincs leírás)}"
  done
}

# eza (ls helyett)
if command -v eza &>/dev/null; then
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza -la --icons=auto --group-directories-first --git'
  alias lt='eza --tree --level=3 --icons=auto'
fi

# fd (Debian/Ubuntu alatt fdfind néven fut)
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
  alias fd='fdfind'
fi

if command -v fastfetch &>/dev/null; then
  alias ff='fastfetch'
elif command -v neofetch &>/dev/null; then
  alias ff='neofetch'
fi

# Egyéb gyorsparancsok
command -v lazygit &>/dev/null && alias lg='lazygit'
command -v trash-put &>/dev/null && alias del='trash-put'

alias -s py='python3'
alias -s lua='lua'
alias -s js='node'
alias -s bf='beef'

alias -s {md,txt,json,conf}='micro'
alias sudo='sudo '
mkcd() {
  [[ -n "${1:-}" ]] || return 1
  mkdir -p -- "$1" && cd -- "$1" || return 1
}
