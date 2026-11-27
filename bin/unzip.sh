#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  echo "Használat: $0 <fajl1.zip> [<fajl2.zip> ...]" >&2
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

# Ellenőrizzük, hogy az unzip elérhető-e
if ! command -v unzip >/dev/null 2>&1; then
  echo "Hiba: az 'unzip' nincs telepítve vagy nem elérhető a PATH-ban." >&2
  exit 2
fi

for i in "$@"; do
  # Kiterjesztés ellenőrzése (case-insensitive)
  zip_file_basename="$(basename -- "$i" 2>/dev/null || basename "$i")"
  case "$zip_file_basename" in
    *.zip|*.ZIP|*.Zip|*.zIp|*.ziP|*.ZIp|*.ZiP|*.zIP) ;;
    *)
      echo "Kihagyva (nem ZIP): $i" >&2
      continue
      ;;
  esac

  # Ellenőrizzük, hogy létezik-e a fájl
  if [[ ! -f "$i" ]]; then
    echo "Hiba: a fájl nem létezik: $i" >&2
    continue
  fi

  # Könyvtár és alapnév
  dir_name="$(dirname -- "$i" 2>/dev/null || dirname "$i")"

  # Belépés a ZIP helyére
  if ! pushd -- "$dir_name" >/dev/null; then
    echo "Hiba: nem lehet belépni: $dir_name" >&2
    continue
  fi

  zip_file="$zip_file_basename"

  # Célkönyvtár név: vágjuk le a .zip-et (case-insensitive)
  name_no_ext="${zip_file%.[Zz][Ii][Pp]}"
  if [[ -z "$name_no_ext" ]]; then
    echo "Hiba: érvénytelen fájlnév a könyvtárhoz: $zip_file" >&2
    popd >/dev/null
    continue
  fi

  if ! mkdir -p -- "$name_no_ext"; then
    echo "Hiba: nem hozható létre könyvtár: $name_no_ext" >&2
    popd >/dev/null
    continue
  fi

  if ! pushd -- "$name_no_ext" >/dev/null; then
    echo "Hiba: nem lehet belépni a könyvtárba: $name_no_ext" >&2
    popd >/dev/null
    continue
  fi

  # Csendes kicsomagolás, felülírás nélküli mód (-n), és NINCS "--"
  if unzip -q -n "../$zip_file"; then
    if ! rm -f -- "../$zip_file"; then
      echo "Figyelem: nem sikerült törölni a ZIP-et: ../$zip_file" >&2
    fi
  else
    echo "Hiba: sikertelen kicsomagolás: ../$zip_file" >&2
  fi

  popd >/dev/null
  popd >/dev/null
done