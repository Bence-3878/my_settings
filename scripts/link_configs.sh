#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -d "$SCRIPT_DIR/config" ]] && REPO_DIR="$SCRIPT_DIR" || REPO_DIR="$(dirname "$SCRIPT_DIR")"
PROFILE="${1:-desktop}"

link_file() {
  local src="$1"
  local dst="$2"
  [[ -e "$src" ]] || return 0
  mkdir -p "$(dirname "$dst")"
  ln -sf "$src" "$dst"
}

# .zshrc biztonsági mentése (ha nem symlink)
if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
  mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
fi

link_file "$REPO_DIR/zsh/zshrc" "$HOME/.zshrc"
link_file "$REPO_DIR/zsh/p10k.zsh" "$HOME/.p10k.zsh"

# Repo útvonal és profil mentése
cat << EOF > "$HOME/.my_settings_env"
export MY_SETTINGS_DIR="$REPO_DIR"
export MY_SETTINGS_PROFILE="$PROFILE"
EOF

# CLI konfigok (szerver + desktop)
link_file "$REPO_DIR/config/fastfetch.jsonc" "$HOME/.config/fastfetch/config.jsonc"
link_file "$REPO_DIR/config/neofetch.conf" "$HOME/.config/neofetch/config.conf"
link_file "$REPO_DIR/config/tmux.conf" "$HOME/.tmux.conf"

# Egyéni Oh My Zsh témák
ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"
mkdir -p "$ZSH_CUSTOM/themes"
for theme in "$REPO_DIR"/zsh/themes/*.zsh-theme; do
  [[ -e "$theme" ]] || continue
  ln -sf "$theme" "$ZSH_CUSTOM/themes/$(basename "$theme")"
done

# Desktop-specifikus konfigok
if [[ "$PROFILE" == "desktop" ]]; then
  link_file "$REPO_DIR/config/terminator.conf" "$HOME/.config/terminator/config"

  if [[ -f "$REPO_DIR/config/ddterm.dconf" ]] && command -v dconf >/dev/null 2>&1 && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    dconf load /com/github/amezin/ddterm/ < "$REPO_DIR/config/ddterm.dconf" || echo "Megjegyzés: ddterm dconf betöltés sikertelen."
  fi
fi

echo "==> Symlinkek létrehozva ($PROFILE profil)."