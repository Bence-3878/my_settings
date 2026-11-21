#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM_DIR="$REPO_DIR/zsh"

# Oh My Zsh telepítése (scriptet nem szakítja meg)
if [[ ! -d "$ZSH_DIR" ]]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

mkdir -p "$ZSH_CUSTOM_DIR/plugins" "$HOME/bin"

# Pluginok klónozása, ha még nincsenek meg
clone_plugin() {
  local repo="$1"
  local dest="$ZSH_CUSTOM_DIR/plugins/$2"
  [[ -d "$dest" ]] || git clone --depth=1 "$repo" "$dest"
}

clone_plugin "https://github.com/zsh-users/zsh-autosuggestions" "zsh-autosuggestions"
clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "zsh-syntax-highlighting"
clone_plugin "https://github.com/zsh-users/zsh-history-substring-search" "zsh-history-substring-search"
clone_plugin "https://github.com/agkozak/zsh-z" "zsh-z"
clone_plugin "https://github.com/MichaelAquilina/zsh-you-should-use" "you-should-use"
clone_plugin "https://github.com/Aloxaf/fzf-tab" "fzf-tab"
clone_plugin "https://github.com/zsh-users/zsh-completions" "zsh-completions"
clone_plugin "https://github.com/hlissner/zsh-autopair" "zsh-autopair"

# Alapértelmezett shell átállítása zsh-ra
TARGET_USER="$(id -un)"
ZSH_PATH="$(command -v zsh)"
if [[ -n "$ZSH_PATH" && "$SHELL" != "$ZSH_PATH" ]]; then
  sudo chsh -s "$ZSH_PATH" "$TARGET_USER" || echo "Megjegyzés: chsh sikertelen, állítsd át manuálisan."
fi