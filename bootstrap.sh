#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/Bence-3878/my_settings.git"
TARGET_DIR="$HOME/my_settings"

# 1. Git telepítése, ha még nincs
if ! command -v git &>/dev/null; then
  if command -v apt &>/dev/null; then sudo apt update && sudo apt install -y git
  elif command -v dnf &>/dev/null; then sudo dnf install -y git
  elif command -v pacman &>/dev/null; then sudo pacman -Sy --noconfirm git
  elif command -v zypper &>/dev/null; then sudo zypper install -y git
  else echo "Telepítsd a git-et manuálisan." >&2; exit 1
  fi
fi

# 2. Klónozás vagy frissítés
if [[ -d "$TARGET_DIR/.git" ]]; then
  git -C "$TARGET_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$TARGET_DIR"
fi

# 3. Fő telepítő indítása (továbbadja a --server / --desktop kapcsolókat is)
exec bash "$TARGET_DIR/install.sh" "$@"