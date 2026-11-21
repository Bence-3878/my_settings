#!/usr/bin/env bash
set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- CSOMAGLISTÁK (minden régi elem, modernizálva) ---
COMMON_PKGS=(
  mc zsh git curl gcc clang gdb speedtest-cli
  sl cowsay lolcat w3m ranger htop btop hexedit tmux
  terminator wine git-cola inxi fzf tree gufw
  micro mplayer unzip flatpak
  eza        # exa utódja
  fastfetch  # neofetch utódja
)

# X11-specifikus csomagok (csak X11 session esetén)
X11_PKGS=(
  numlockx
  guake
)

# Flatpak GUI appok (disztrófüggetlen, Remmina pluginokkal együtt)
FLATPAK_APPS=(
  org.gimp.GIMP
  org.remmina.Remmina
)

# --- CSOMAGKEZELŐ FELISMERÉSE ---
detect_pm() {
  if command -v apt &>/dev/null; then echo "apt"
  elif command -v dnf &>/dev/null; then echo "dnf"
  elif command -v pacman &>/dev/null; then echo "pacman"
  elif command -v zypper &>/dev/null; then echo "zypper"
  else echo "unknown"
  fi
}

PM="$(detect_pm)"
if [[ "$PM" == "unknown" ]]; then
  echo "Hiba: Nem támogatott csomagkezelő." >&2
  exit 1
fi

# Disztrónként eltérő nevű csomagok
DISTRO_PKGS=()
case "$PM" in
  apt)
    DISTRO_PKGS=(g++ openssh-server w3m-img fonts-powerline default-jre)
    sudo apt update && sudo apt upgrade -y
    ;;
  dnf)
    DISTRO_PKGS=(gcc-c++ openssh-server powerline-fonts java-latest-openjdk)
    sudo dnf upgrade -y
    ;;
  pacman)
    DISTRO_PKGS=(openssh powerline-fonts jre-openjdk)
    sudo pacman -Syu --noconfirm
    ;;
  zypper)
    DISTRO_PKGS=(gcc-c++ openssh powerline-fonts java-21-openjdk)
    sudo zypper refresh && sudo zypper update -y
    ;;
esac

# --- TELEPÍTŐ FÜGGVÉNY (nem áll le 1 hiányzó csomagnál) ---
FAILED_PKGS=()
install_pkg() {
  local pkg="$1"
  echo "==> Telepítés: $pkg"
  case "$PM" in
    apt)    sudo apt install -y "$pkg" || FAILED_PKGS+=("$pkg") ;;
    dnf)    sudo dnf install -y "$pkg" || FAILED_PKGS+=("$pkg") ;;
    pacman) sudo pacman -S --noconfirm --needed "$pkg" || FAILED_PKGS+=("$pkg") ;;
    zypper) sudo zypper install -y "$pkg" || FAILED_PKGS+=("$pkg") ;;
  esac
}

# --- ALAP + DISZTRÓ CSOMAGOK ---
for pkg in "${COMMON_PKGS[@]}" "${DISTRO_PKGS[@]}"; do
  install_pkg "$pkg"
done

# --- X11 ELLENŐRZÉS ---
if [[ "${XDG_SESSION_TYPE:-}" == "x11" ]]; then
  echo "==> X11 detektálva, X11 csomagok telepítése..."
  for pkg in "${X11_PKGS[@]}"; do
    install_pkg "$pkg"
  done
else
  echo "==> Nem X11 session (${XDG_SESSION_TYPE:-ismeretlen}), X11 csomagok kihagyva."
fi

# --- FLATPAK ---
if command -v flatpak &>/dev/null; then
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  flatpak install -y flathub "${FLATPAK_APPS[@]}"
fi

# --- ZSH ÉS KONFIGOK ---
bash "$REPO_DIR/setup_zsh.sh"
bash "$REPO_DIR/link_configs.sh"

# --- ÖSSZESÍTÉS ---
echo "========================================"
echo "Kész!"
if (( ${#FAILED_PKGS[@]} > 0 )); then
  echo "Nem települt (manuálisan ellenőrizendő): ${FAILED_PKGS[*]}"
fi
echo "Megjegyzés: espanso, linux-wifi-hotspot és uex nem minden disztrón érhető el alap repóból."