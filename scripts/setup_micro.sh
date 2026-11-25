#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -d "$SCRIPT_DIR/config" ]] && REPO_DIR="$SCRIPT_DIR" || REPO_DIR="$(dirname "$SCRIPT_DIR")"

MICRO_CONFIG_DIR="$HOME/.config/micro"
REPO_MICRO_DIR="$REPO_DIR/config/micro"

# 1. Micro telepítése, ha hiányzik
if ! command -v micro >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y micro
  else
    mkdir -p "$HOME/.local/bin"
    (cd "$HOME/.local/bin" && curl -fsSL https://getmic.ro | bash)
  fi
fi

# 2. Alapbeállítások írása a repóba és szimlinkelés
mkdir -p "$REPO_MICRO_DIR" "$MICRO_CONFIG_DIR"

cat << 'EOF' > "$REPO_MICRO_DIR/settings.json"
{
    "autoindent": true,
    "clipboard": "external",
    "colorscheme": "monokai",
    "mkparents": true,
    "ruler": true,
    "savecursor": true,
    "saveundo": true,
    "scrollbar": true,
    "softwrap": true,
    "tabsize": 4,
    "tabstospaces": true
}
EOF

ln -sf "$REPO_MICRO_DIR/settings.json" "$MICRO_CONFIG_DIR/settings.json"

# 3. Pluginok telepítése
PLUGINS=(
  filemanager
  fzf
  jump
  detectindent
  bounce
  quoter
  manipulator
  # lsp
)

for plugin in "${PLUGINS[@]}"; do
  if [[ ! -d "$MICRO_CONFIG_DIR/plug/$plugin" ]]; then
    micro -plugin install "$plugin"
  fi
done

echo "==> Micro telepítve, beállítva és szimlinkelve."