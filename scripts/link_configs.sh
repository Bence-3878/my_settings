#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# .zshrc symlink (mentés, ha létezett nem-symlink fájl)
if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
  mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
fi
ln -sf "$REPO_DIR/zsh/zshrc" "$HOME/.zshrc"

# Repo útvonal mentése, hogy a .zshrc ne függjön a fix ~/mis mappától
PROFILE="${1:-desktop}"
cat << EOF > "$HOME/.my_settings_env"
export MY_SETTINGS_DIR="$REPO_DIR"
export MY_SETTINGS_PROFILE="$PROFILE"
EOF

mkdir -p "$HOME/.config/fastfetch"
ln -sf "$REPO_DIR/config/fastfetch.jsonc" "$HOME/.config/fastfetch/config.jsonc"

mkdir -p "$HOME/.config/neofetch"
ln -sf "$REPO_DIR/config/neofetch.conf" "$HOME/.config/neofetch/config.conf"

mkdir -p "$HOME/.config/terminator"
ln -sf "$REPO_DIR/config/terminator.conf" "$HOME/.config/terminator/config"

ln -sf "$REPO_DIR/config/tmux.conf" "$HOME/.tmux.conf"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$ZSH_CUSTOM/themes"

for theme in "$REPO_DIR"/zsh/themes/*.zsh-theme; do
  [ -e "$theme" ] || continue
  ln -sf "$theme" "$ZSH_CUSTOM/themes/$(basename "$theme")"
done

dconf load /com/github/amezin/ddterm/ < "$REPO_DIR/config/ddterm.dconf"

echo "==> Symlinkek létrehozva."