#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# .zshrc symlink (mentés, ha létezett nem-symlink fájl)
if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
  mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
fi
ln -sf "$REPO_DIR/zshrc" "$HOME/.zshrc"

# Repo útvonal mentése, hogy a .zshrc ne függjön a fix ~/mis mappától
echo "export MY_SETTINGS_DIR=\"$REPO_DIR\"" > "$HOME/.my_settings_env"

# Neofetch konfig (ha még használod)
if [[ -f "$REPO_DIR/config/neofetch.conf" ]]; then
  mkdir -p "$HOME/.config/neofetch"
  ln -sf "$REPO_DIR/config/neofetch.conf" "$HOME/.config/neofetch/config.conf"
fi

echo "==> Symlinkek létrehozva."