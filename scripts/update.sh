#!/usr/bin/env bash
set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
[[ -d "$SCRIPT_DIR/config" ]] && REPO_DIR="$SCRIPT_DIR" || REPO_DIR="$(dirname "$SCRIPT_DIR")"

UPDATE_SYSTEM=1

usage() {
  echo "Használat: $0 [--no-system | -n] [--help | -h]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-system|-n)
      UPDATE_SYSTEM=0
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Ismeretlen kapcsoló: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -f "$HOME/.my_settings_env" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/.my_settings_env"
fi

PROFILE="${MY_SETTINGS_PROFILE:-desktop}"
ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM="$ZSH_DIR/custom"

update_repo() {
  echo "==> Saját repó frissítése ($REPO_DIR)..."
  if ! command -v git >/dev/null 2>&1 || [[ ! -d "$REPO_DIR/.git" ]]; then
    echo "Figyelem: git vagy .git könyvtár nem található, kihagyva."
    return 0
  fi

  if git -C "$REPO_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    git -C "$REPO_DIR" pull --ff-only || echo "Figyelem: a repó pull sikertelen." >&2
  else
    echo "Megjegyzés: nincs beállított upstream ág, git pull kihagyva."
  fi
}

update_system() {
  (( UPDATE_SYSTEM == 1 )) || { echo "==> Rendszercsomagok frissítése kihagyva (--no-system)."; return 0; }

  echo "==> Rendszercsomagok frissítése..."
  if command -v apt >/dev/null 2>&1; then
    sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf upgrade -y
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Syu --noconfirm
  elif command -v zypper >/dev/null 2>&1; then
    sudo zypper refresh && sudo zypper update -y
  else
    echo "Figyelem: nem található támogatott csomagkezelő." >&2
  fi

  if command -v flatpak >/dev/null 2>&1; then
    echo "==> Flatpak alkalmazások frissítése..."
    flatpak update -y || echo "Figyelem: flatpak update sikertelen." >&2
  fi
}

update_git_dir() {
  local dir="$1"
  [[ -d "$dir/.git" ]] || return 0
  echo "  -> Frissítés: $(basename "$dir")"
  git -C "$dir" pull --ff-only || echo "Figyelem: sikertelen frissítés ($dir)." >&2
}

update_zsh() {
  echo "==> Oh My Zsh, pluginok és témák frissítése..."
  update_git_dir "$ZSH_DIR"

  ZSH="$ZSH_DIR" ZSH_CUSTOM="$ZSH_CUSTOM" bash "$REPO_DIR/scripts/setup_zsh.sh"

  shopt -s nullglob
  for dir in "$ZSH_CUSTOM"/plugins/* "$ZSH_CUSTOM"/themes/*; do
    [[ -d "$dir" ]] && update_git_dir "$dir"
  done
  shopt -u nullglob
}

update_micro() {
  command -v micro >/dev/null 2>&1 || return 0
  echo "==> Micro beállítások és pluginok frissítése..."
  bash "$REPO_DIR/scripts/setup_micro.sh"
  micro -plugin update || echo "Figyelem: micro plugin frissítés sikertelen." >&2
}

update_repo
update_system
update_zsh
update_micro

echo "==> Konfigurációk és saját binárisok frissítése ($PROFILE profil)..."
ZSH_CUSTOM="$ZSH_CUSTOM" bash "$REPO_DIR/scripts/link_configs.sh" "$PROFILE"
bash "$REPO_DIR/scripts/build_bin.sh" --force

if command -v tldr >/dev/null 2>&1; then
  echo "==> tldr adatbázis frissítése..."
  tldr --update || true
fi

echo "==> Minden frissítve ($PROFILE profil)."
