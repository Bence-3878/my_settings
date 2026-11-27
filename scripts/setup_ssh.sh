#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -d "$SCRIPT_DIR/config" ]] && REPO_DIR="$SCRIPT_DIR" || REPO_DIR="$(dirname "$SCRIPT_DIR")"

MODE="${1:-both}" # client | server | both

install_pkg() {
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y "$@"
  fi
}

setup_client() {
  command -v xauth >/dev/null 2>&1 || install_pkg xauth

  mkdir -p "$HOME/.ssh/config.d" "$REPO_DIR/config"
  chmod 700 "$HOME/.ssh" "$HOME/.ssh/config.d"

  cat << 'EOF' > "$REPO_DIR/config/ssh_x11.conf"
Host *
    ForwardX11 yes
    ForwardX11Trusted yes
EOF
  chmod 600 "$REPO_DIR/config/ssh_x11.conf"

  ln -sf "$REPO_DIR/config/ssh_x11.conf" "$HOME/.ssh/config.d/10-x11.conf"

  # Include sor biztosítása a fő ~/.ssh/config elején
  touch "$HOME/.ssh/config"
  chmod 600 "$HOME/.ssh/config"
  if ! grep -q '^Include config.d/\*\.conf' "$HOME/.ssh/config"; then
    tmp_cfg="$(mktemp)"
    printf 'Include config.d/*.conf\n\n' > "$tmp_cfg"
    cat "$HOME/.ssh/config" >> "$tmp_cfg"
    mv "$tmp_cfg" "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
  fi

  echo "==> SSH kliens X11 forwarding beállítva."
}

setup_server() {
  command -v sshd >/dev/null 2>&1 || install_pkg openssh-server
  command -v xauth >/dev/null 2>&1 || install_pkg xauth

  sudo mkdir -p /etc/ssh/sshd_config.d
  cat << 'EOF' | sudo tee /etc/ssh/sshd_config.d/99-x11.conf >/dev/null
X11Forwarding yes
X11DisplayOffset 10
X11UseLocalhost yes
EOF

  # Include biztosítása régebbi sshd_config esetén
  if ! sudo grep -q '^Include /etc/ssh/sshd_config.d/\*\.conf' /etc/ssh/sshd_config; then
    echo 'Include /etc/ssh/sshd_config.d/*.conf' | sudo tee -a /etc/ssh/sshd_config >/dev/null
  fi

  sudo sshd -t
  sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd
  echo "==> SSH szerver (sshd) X11 forwarding beállítva."
}

case "$MODE" in
  client) setup_client ;;
  server) setup_server ;;
  both)   setup_client; setup_server ;;
  *)      echo "Használat: $0 [client|server|both]"; exit 1 ;;
esac

set -eE
trap 'echo "Sikertelen parancs (${BASH_SOURCE[0]}:$LINENO): $BASH_COMMAND" >&2' ERR