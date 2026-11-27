#!/usr/bin/env bash
set -e

# Nem interaktív módban (pl. automata Docker teszt) azonnal kilép, hogy ne akassza meg a telepítőt
[[ -t 0 ]] || exit 0

SSH_DIR="$HOME/.ssh"
CONF_DIR="$SSH_DIR/config.d"
LOCAL_CONF="$CONF_DIR/99-local.conf"

mkdir -p "$CONF_DIR"
chmod 700 "$SSH_DIR" "$CONF_DIR"
touch "$SSH_DIR/config" "$LOCAL_CONF"
chmod 600 "$SSH_DIR/config" "$LOCAL_CONF"

# Include sor biztosítása a ~/.ssh/config elején
if ! grep -q '^Include config.d/\*\.conf' "$SSH_DIR/config"; then
  tmp_cfg="$(mktemp)"
  printf 'Include config.d/*.conf\n\n' > "$tmp_cfg"
  cat "$SSH_DIR/config" >> "$tmp_cfg"
  mv "$tmp_cfg" "$SSH_DIR/config"
  chmod 600 "$SSH_DIR/config"
fi

while true; do
  read -rp "Szeretnél felvenni egy távoli SSH gépet? [i/N]: " ans
  [[ "$ans" =~ ^[iIyY]$ ]] || break

  read -rp "  Rövid név (pl. rpi, vps): " host_alias
  [[ -z "$host_alias" ]] && { echo "  Üres név, kihagyva."; continue; }

  if grep -qE "^Host[[:space:]]+$host_alias$" "$LOCAL_CONF"; then
    echo "  Figyelem: '$host_alias' már létezik a $LOCAL_CONF fájlban, kihagyva."
    continue
  fi

  read -rp "  IP cím vagy domain: " host_name
  [[ -z "$host_name" ]] && { echo "  Üres cím, kihagyva."; continue; }

  read -rp "  Felhasználónév [$USER]: " ssh_user
  ssh_user="${ssh_user:-$USER}"

  read -rp "  Port [22]: " ssh_port
  ssh_port="${ssh_port:-22}"

  read -rp "  Privát kulcs útvonala (Enter = alapértelmezett): " id_file

  {
    echo ""
    echo "Host $host_alias"
    echo "    HostName $host_name"
    echo "    User $ssh_user"
    echo "    Port $ssh_port"
    [[ -n "$id_file" ]] && echo "    IdentityFile $id_file"
  } >> "$LOCAL_CONF"

  echo "  ==> '$host_alias' elmentve ($LOCAL_CONF)."
done