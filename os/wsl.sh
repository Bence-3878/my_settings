#!/usr/bin/env bash
set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- 1. PROFIL KIVÁLASZTÁSA (--wsl | --server | --desktop) ---
PROFILE=""
case "${1:-}" in
  --wsl|-w|--desktop|-d|"")
    PROFILE="wsl"
    ;;
  --server|-s)
    PROFILE="server"
    ;;
  *)
    echo "Használat: $0 [--wsl | --server]" >&2
    exit 1
    ;;
esac
echo "==> Kiválasztott profil: $PROFILE (WSL környezet)"

if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  echo "==> WSL disztribúció: $WSL_DISTRO_NAME"
fi

# Sudo előkészítése (ha nem rootként fut)
SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  if ! command -v sudo &>/dev/null; then
    echo "Hiba: nincs 'sudo' telepítve, és a script nem rootként fut." >&2
    exit 1
  fi
  if [[ -n "${SUDO_ASKPASS:-}" ]]; then
    SUDO="sudo -A"
  else
    SUDO="sudo"
  fi
  $SUDO -v || { echo "Hiba: sudo jogosultság szükséges a csomagok telepítéséhez." >&2; exit 1; }
fi

# --- 2. CSOMAGLISTÁK (WSL-re optimalizálva) ---
BASE_PKGS=(
  ca-certificates tar mc zsh git curl fzf tree htop btop tmux ranger
  micro unzip inxi hexedit
  eza fastfetch tealdeer sl gcc clang
  ripgrep ncdu duf jq trash-cli
  bat xclip wl-clipboard
)

# --- 3. CSOMAGKEZELŐ FELISMERÉSE ---
detect_pm() {
  if command -v apt-get &>/dev/null; then echo "apt"
  elif command -v dnf &>/dev/null; then echo "dnf"
  elif command -v pacman &>/dev/null; then echo "pacman"
  elif command -v zypper &>/dev/null; then echo "zypper"
  else echo "unknown"
  fi
}

PM="$(detect_pm)"
[[ "$PM" == "unknown" ]] && { echo "Nem támogatott csomagkezelő." >&2; exit 1; }

DISTRO_BASE=()
case "$PM" in
  apt)
    DISTRO_BASE=(gh openssh-client g++ fd-find mtr-tiny xz-utils fontconfig wslu)
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get update && \
      $SUDO env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    ;;
  dnf)
    DISTRO_BASE=(gh openssh-clients gcc-c++ fd-find mtr xz fontconfig util-linux-user)
    $SUDO dnf upgrade -y
    ;;
  pacman)
    DISTRO_BASE=(github-cli openssh fd mtr lazygit xz fontconfig)
    if [[ ! -s /etc/pacman.d/gnupg/pubring.gpg ]]; then
      $SUDO pacman-key --init && $SUDO pacman-key --populate archlinux
    fi
    $SUDO pacman -Syu --noconfirm
    ;;
  zypper)
    DISTRO_BASE=(gh openssh gcc-c++ fd mtr lazygit xz fontconfig)
    $SUDO zypper refresh && $SUDO zypper update -y
    ;;
esac

# --- 4. TELEPÍTÉS (gyors csoportos telepítés, hiba esetén egyenkénti fallback) ---
FAILED_PKGS=()
install_pkg() {
  local pkg="$1"
  echo "==> Telepítés: $pkg"
  case "$PM" in
    apt)    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" || FAILED_PKGS+=("$pkg") ;;
    dnf)    $SUDO dnf install -y "$pkg" || FAILED_PKGS+=("$pkg") ;;
    pacman) $SUDO pacman -S --noconfirm --needed "$pkg" || FAILED_PKGS+=("$pkg") ;;
    zypper) $SUDO zypper install -y "$pkg" || FAILED_PKGS+=("$pkg") ;;
  esac
}

install_all_pkgs() {
  local pkgs=("$@")
  echo "==> Csomagok telepítése ($PM)..."
  case "$PM" in
    apt)    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}" && return 0 ;;
    dnf)    $SUDO dnf install -y "${pkgs[@]}" && return 0 ;;
    pacman) $SUDO pacman -S --noconfirm --needed "${pkgs[@]}" && return 0 ;;
    zypper) $SUDO zypper install -y "${pkgs[@]}" && return 0 ;;
  esac

  echo "Figyelem: csoportos telepítésnél hiányzó csomag volt, egyenkénti telepítés következik..."
  for pkg in "${pkgs[@]}"; do
    install_pkg "$pkg"
  done
}

install_lazygit() {
  command -v lazygit &>/dev/null && return 0
  command -v jq &>/dev/null || { echo "lazygit: jq hiányzik, kihagyva."; return 0; }
  local ver arch
  ver=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | jq -r '.tag_name | ltrimstr("v")') || true
  if [[ -z "$ver" || "$ver" == "null" ]]; then
    echo "Figyelmeztetés: lazygit verzió lekérdezése sikertelen." >&2
    return 0
  fi
  case "$(uname -m)" in
    x86_64)  arch="x86_64" ;;
    aarch64) arch="arm64" ;;
    *) echo "lazygit: nem támogatott architektúra"; return 0 ;;
  esac
  echo "==> lazygit ($ver) telepítése..."
  if ! curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${ver}/lazygit_${ver}_Linux_${arch}.tar.gz" \
    | $SUDO tar -xz -C /usr/local/bin lazygit; then
    echo "Figyelmeztetés: lazygit telepítése sikertelen." >&2
  fi
}

install_all_pkgs "${BASE_PKGS[@]}" "${DISTRO_BASE[@]}"
install_lazygit

# --- 5. ZSH, KONFIGOK ÉS BINÁRISOK ---
bash "$REPO_DIR/scripts/setup_zsh.sh"
bash "$REPO_DIR/scripts/link_configs.sh" "$PROFILE"
bash "$REPO_DIR/scripts/build_bin.sh"

command -v tldr &>/dev/null && tldr --update || true

echo "========================================"
echo "Kész ($PROFILE profil)!"
(( ${#FAILED_PKGS[@]} > 0 )) && echo "Nem települt (kihagyva): ${FAILED_PKGS[*]}"
echo "Tipp: A Zsh Powerline/Nerd Font ikonokhoz állíts be egy Nerd Fontot (pl. JetBrainsMono Nerd Font) a Windows Terminalban!"
