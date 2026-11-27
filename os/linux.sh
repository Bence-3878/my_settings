#!/usr/bin/env bash
set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
    if [[ -t 0 ]]; then
      read -rp "Profil kiválasztása [server/desktop] (alap: $DEFAULT_PROFILE): " INPUT
      PROFILE="${INPUT:-$DEFAULT_PROFILE}"
    else
      PROFILE="$DEFAULT_PROFILE"
    fi
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

# --- 2. CSOMAGLISTÁK ---
# Mindkettőre megy (RPi szerver + laptop)
BASE_PKGS=(
  mc zsh git gh curl fzf tree htop btop tmux ranger
  micro unzip inxi speedtest-cli hexedit
  eza fastfetch tealdeer sl gcc clang
  ripgrep ncdu duf jq trash-cli
)

# Csak szerverre (pl. RPi)
SERVER_PKGS=(
  ufw
)

# Csak asztali gépre (laptop)
DESKTOP_PKGS=(
  gdb cowsay lolcat w3m bat
  terminator wine git-cola gufw mplayer flatpak
  flameshot copyq meld syncthing fontconfig
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
    DISTRO_BASE=(g++ openssh-server fd-find mtr-tiny)
    DISTRO_DESKTOP=(w3m-img fonts-powerline default-jre xz-utils)
    sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
    ;;
  dnf)
    DISTRO_BASE=(gcc-c++ openssh-server fd-find mtr)
    DISTRO_DESKTOP=(powerline-fonts java-latest-openjdk xz)
    sudo dnf upgrade -y
    ;;
  pacman)
    DISTRO_BASE=(openssh fd mtr lazygit)
    DISTRO_DESKTOP=(powerline-fonts jre-openjdk xz)
    sudo pacman -Syu --noconfirm
    ;;
  zypper)
    DISTRO_BASE=(gcc-c++ openssh fd mtr lazygit)
    DISTRO_DESKTOP=(powerline-fonts java-21-openjdk xz)
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

install_espanso() {
  command -v espanso &>/dev/null && return
  echo "==> Espanso telepítése..."

  local session="${XDG_SESSION_TYPE:-x11}"
  local tmp_deb="/tmp/espanso.deb"

  if [[ "$PM" == "apt" ]]; then
    if [[ "$session" == "wayland" ]]; then
      curl -fSL "https://github.com/espanso/espanso/releases/latest/download/espanso-debian-wayland-amd64.deb" -o "$tmp_deb"
    else
      curl -fSL "https://github.com/espanso/espanso/releases/latest/download/espanso-debian-x11-amd64.deb" -o "$tmp_deb"
    fi
    sudo apt install -y "$tmp_deb"
    rm -f "$tmp_deb"
  elif [[ "$PM" == "pacman" ]] && command -v yay &>/dev/null; then
    yay -S --noconfirm "espanso-${session}"
  elif [[ "$session" == "x11" ]]; then
    # Disztrófüggetlen X11 fallback (AppImage)
    mkdir -p "$HOME/bin"
    curl -fSL "https://github.com/espanso/espanso/releases/latest/download/Espanso-X11.AppImage" -o "$HOME/bin/espanso"
    chmod +x "$HOME/bin/espanso"
  else
    echo "Figyelem: Espanso Wayland alatt ezen a disztrón manuális telepítést igényel." >&2
    return
  fi

  espanso service register
  espanso start
}

install_uex() {
  command -v uex &>/dev/null && return
  echo "==> UltraEdit (uex) telepítése..."

  case "$PM" in
    apt)
      local tmp="/tmp/uex.deb"
      curl -fSL "https://downloads.ultraedit.com/main/ue/linux/uex_amd64.deb" -o "$tmp"
      sudo apt install -y "$tmp"
      rm -f "$tmp"
      ;;
    dnf)
      local tmp="/tmp/uex.rpm"
      curl -fSL "https://downloads.ultraedit.com/main/ue/linux/uex_x86_64.rpm" -o "$tmp"
      sudo dnf install -y "$tmp"
      rm -f "$tmp"
      ;;
    pacman)
      command -v yay &>/dev/null && yay -S --noconfirm uex
      ;;
  esac
}

install_lazygit() {
  command -v lazygit &>/dev/null && return 0
  local ver arch
  ver=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | jq -r '.tag_name | ltrimstr("v")')
  case "$(uname -m)" in
    x86_64)  arch="x86_64" ;;
    aarch64) arch="arm64" ;;
    *) echo "lazygit: nem támogatott architektúra"; return 0 ;;
  esac
  curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${ver}/lazygit_${ver}_Linux_${arch}.tar.gz" \
    | sudo tar -xz -C /usr/local/bin lazygit
}

install_nerd_font() {
  local font_name="JetBrainsMono"
  local font_dir="$HOME/.local/share/fonts/$font_name"

  if [[ -d "$font_dir" ]] && [[ -n "$(ls -A "$font_dir" 2>/dev/null)" ]]; then
    echo "==> $font_name Nerd Font már telepítve van."
    return 0
  fi

  echo "==> $font_name Nerd Font telepítése..."
  mkdir -p "$font_dir"
  local tmp_file="/tmp/${font_name}.tar.xz"

  if curl -fLsS -o "$tmp_file" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.tar.xz"; then
    tar -xf "$tmp_file" -C "$font_dir"
    rm -f "$tmp_file"
    command -v fc-cache &>/dev/null && fc-cache -f "$font_dir"
  else
    echo "Figyelmeztetés: $font_name Nerd Font letöltése sikertelen."
    rm -f "$tmp_file"
  fi
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

  install_espanso
  install_uex
  install_lazygit
  install_nerd_font
fi

# --- 5. ZSH ÉS KONFIGOK ---
bash "$REPO_DIR/scripts/setup_zsh.sh"
bash "$REPO_DIR/scripts/link_configs.sh" "$PROFILE"
bash "$REPO_DIR/scripts/build_bin.sh"

command -v tldr &>/dev/null && tldr --update || true

echo "========================================"
echo "Kész ($PROFILE profil)!"
if (( ${#FAILED_PKGS[@]} > 0 )); then
  echo "Nem települt: ${FAILED_PKGS[*]}"
fi

set -eE
trap 'echo "Sikertelen parancs (${BASH_SOURCE[0]}:$LINENO): $BASH_COMMAND" >&2' ERR