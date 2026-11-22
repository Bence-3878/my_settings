#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# .zshrc symlink (mentés, ha létezett nem-symlink fájl)
if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
  mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
fi
ln -sf "$REPO_DIR/zshrc" "$HOME/.zshrc"

# Repo útvonal mentése, hogy a .zshrc ne függjön a fix ~/mis mappától
PROFILE="${1:-desktop}"
cat << EOF > "$HOME/.my_settings_env"
export MY_SETTINGS_DIR="$REPO_DIR"
export MY_SETTINGS_PROFILE="$PROFILE"
EOF

mkdir -p "$HOME/.config/fastfetch"
ln -sf "$REPO_DIR/config/fastfetch.jsonc" "$HOME/.config/fastfetch/config.jsonc"

echo "==> Symlinkek létrehozva."