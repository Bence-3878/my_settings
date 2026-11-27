#!/usr/bin/env bash
set -e

ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM="$ZSH_DIR/custom"

# Oh My Zsh telepítése (scriptet nem szakítja meg)
if [[ ! -d "$ZSH_DIR" ]]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

mkdir -p "$ZSH_CUSTOM/plugins" "$ZSH_CUSTOM/themes"

clone_plugin() {
  local repo="$1"
  local dest="$ZSH_CUSTOM/plugins/$2"
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

if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
fi

# Alapértelmezett shell átállítása zsh-ra
TARGET_USER="$(id -un)"
if [[ -x /usr/bin/zsh ]]; then
  ZSH_PATH="/usr/bin/zsh"
elif [[ -x /bin/zsh ]]; then
  ZSH_PATH="/bin/zsh"
else
  ZSH_PATH="$(command -v zsh || true)"
fi
if [[ -n "$ZSH_PATH" && "$SHELL" != "$ZSH_PATH" ]] && command -v chsh >/dev/null 2>&1; then
  if [[ "$(id -u)" -eq 0 ]]; then
    chsh -s "$ZSH_PATH" "$TARGET_USER" || echo "Megjegyzés: chsh sikertelen."
  elif command -v sudo >/dev/null 2>&1; then
    if [[ -n "${SUDO_ASKPASS:-}" ]]; then
      sudo -A chsh -s "$ZSH_PATH" "$TARGET_USER" || echo "Megjegyzés: chsh sikertelen, állítsd át manuálisan."
    else
      sudo chsh -s "$ZSH_PATH" "$TARGET_USER" || echo "Megjegyzés: chsh sikertelen, állítsd át manuálisan."
    fi
  fi
fi

set -eE
trap 'echo "Sikertelen parancs (${BASH_SOURCE[0]}:$LINENO): $BASH_COMMAND" >&2' ERR