#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -d "$SCRIPT_DIR/config" ]] && REPO_DIR="$SCRIPT_DIR" || REPO_DIR="$(dirname "$SCRIPT_DIR")"
OUT_DIR="$HOME/bin"
mkdir -p "$OUT_DIR"

FORCE=0
if [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]]; then
  FORCE=1
fi

# Fordító keresése
CC="$(command -v gcc || command -v clang || command -v cc || true)"
if [[ -z "$CC" ]]; then
  echo "Figyelem: nincs C fordító (gcc/clang), a binárisok fordítása kihagyva." >&2
  exit 0
fi

shopt -s nullglob
for src in "$REPO_DIR"/src/*.c "$REPO_DIR"/bin/*.c; do
  name="$(basename "$src" .c)"
  out="$OUT_DIR/$name"

  # Alapból csak akkor fordít, ha hiányzik vagy módosult a .c fájl; --force esetén mindig
  if (( FORCE == 1 )) || [[ ! -f "$out" || "$src" -nt "$out" ]]; then
    echo "==> Fordítás: $name ($CC)"
    "$CC" -O2 -Wall "$src" -o "$out"
  fi
done