#!/usr/bin/env bash
set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- 1. PROFIL KIVÁLASZTÁSA (--server | --desktop | auto) ---
PROFILE=""
case "${1:-}" in
  --server|-s)  PROFILE="server" ;;
  --desktop|-d) PROFILE="desktop" ;;
  "")
    if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || grep -qi "raspberry pi" /proc/device-tree/model 2>/dev/null; then
      DEFAULT_PROFILE="server"
    else
      DEFAULT_PROFILE="desktop"
    fi
    read -rp "Profil kiválasztása [server/desktop] (alap: $DEFAULT_PROFILE): " INPUT
    PROFILE="${INPUT:-$DEFAULT_PROFILE}"
    ;;
  *)
    echo "Használat: $0 [--server | --desktop]" >&2
    exit 1
    ;;
esac

if [[ "$PROFILE" != "server" && "$PROFILE" != "desktop" ]]; then
  echo "Hiba: Érvénytelen profil ($PROFILE). Használd: server vagy desktop." >&2
  exit 1
fi
echo "==> Kiválasztott profil: $PROFILE"

bash "$REPO_DIR/link_configs.sh" "$PROFILE"

# --- 2. CSOMAGLISTÁK ---
# Mindkettőre megy (RPi szerver + laptop)
BASE_PKGS=(
  mc zsh git curl fzf tree htop btop tmux ranger
  micro unzip inxi speedtest-cli hexedit
  eza fastfetch
)

# Csak szerverre (pl. RPi)
SERVER_PKGS=(
  ufw
)

# Csak asztali gépre (laptop)
DESKTOP_PKGS=(
  gcc clang gdb sl cowsay lolcat w3m
  terminator wine git-cola gufw mplayer flatpak
)

# Csak asztali + X11
X11_PKGS=(
  numlockx guake
)

# Csak asztali (Flatpak)
FLATPAK_APPS=(
  org.gimp.GIMP
  org.remmina.Remmina
)

# --- 3. CSOMAGKEZELŐ FELISMERÉSE ---
detect_pm() {
  if command -v apt &>/dev/null; then echo "apt"
  elif command -v dnf &>/dev/null; then echo "dnf"
  elif command -v pacman &>/dev/null; then echo "pacman"
  elif command -v zypper &>/dev/null; then echo "zypper"
  else echo "unknown"
  fi
}

PM="$(detect_pm)"
[[ "$PM" == "unknown" ]] && { echo "Nem támogatott csomagkezelő." >&2; exit 1; }

DISTRO_BASE=()
DISTRO_DESKTOP=()
case "$PM" in
  apt)
    DISTRO_BASE=(openssh-server)
    DISTRO_DESKTOP=(g++ w3m-img fonts-powerline default-jre)
    sudo apt update && sudo apt upgrade -y
    ;;
  dnf)
    DISTRO_BASE=(openssh-server)
    DISTRO_DESKTOP=(gcc-c++ powerline-fonts java-latest-openjdk)
    sudo dnf upgrade -y
    ;;
  pacman)
    DISTRO_BASE=(openssh)
    DISTRO_DESKTOP=(powerline-fonts jre-openjdk)
    sudo pacman -Syu --noconfirm
    ;;
  zypper)
    DISTRO_BASE=(openssh)
    DISTRO_DESKTOP=(gcc-c++ powerline-fonts java-21-openjdk)
    sudo zypper refresh && sudo zypper update -y
    ;;
esac

# --- 4. TELEPÍTÉS ---
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

# Alap csomagok (mindig)
for pkg in "${BASE_PKGS[@]}" "${DISTRO_BASE[@]}"; do
  install_pkg "$pkg"
done

# Profilfüggő csomagok
if [[ "$PROFILE" == "server" ]]; then
  for pkg in "${SERVER_PKGS[@]}"; do
    install_pkg "$pkg"
  done
else
  for pkg in "${DESKTOP_PKGS[@]}" "${DISTRO_DESKTOP[@]}"; do
    install_pkg "$pkg"
  done

  if [[ "${XDG_SESSION_TYPE:-}" == "x11" ]]; then
    echo "==> X11 detektálva..."
    for pkg in "${X11_PKGS[@]}"; do
      install_pkg "$pkg"
    done
  fi

  if command -v flatpak &>/dev/null; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub "${FLATPAK_APPS[@]}"
  fi
fi

# --- 5. ZSH ÉS KONFIGOK ---
bash "$REPO_DIR/setup_zsh.sh"
bash "$REPO_DIR/link_configs.sh"

echo "========================================"
echo "Kész ($PROFILE profil)!"
(( ${#FAILED_PKGS[@]} > 0 )) && echo "Nem települt: ${FAILED_PKGS[*]}"