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


for i in "$@"; do
    #if [[ "$i" =~ ^[+-]?[0-9]+$ ]]; then
    #    if (( 10#$i == 0 )); then
    #        echo "nulla"
    #    fi
    #else
    #if [ "${i:(-4)}" = ".zip" ]; then
    #    d="${i%/*}"
    #    cd "$d"
    #    n="${i##*/}" #echo "${i##*/}" | sed 's/\.zip$//'
    #    n="${n%????}"
    #    mkdir -p "$n"
        #cd "${i%????}"
    #    cd "$n"
    #    if unzip "$i"; then rm "$i"; fi
    #continue
  fi

  dir_name="$(dirname -- "$i")"
  # Belépünk abba a könyvtárba, ahol a ZIP van (így a relatív utak stabilak)
  if ! pushd "$dir_name" >/dev/null; then
    echo "Hiba: nem lehet belépni: $dir_name" >&2
    continue
  fi

  # Célkönyvtár neve: fájlnév kiterjesztés nélkül
  zip_file="$(basename -- "$i")"     # pl. valami.Archive.ZIP
  name_no_ext="${zip_file%.*}"       # pl. valami.Archive

  # Létrehozzuk a cél mappát (ha létezik, nem baj)
  if ! mkdir -p -- "$name_no_ext"; then
    echo "Hiba: nem hozható létre könyvtár: $name_no_ext" >&2
    popd >/dev/null
    continue
  fi

  # Kicsomagolás a célkönyvtárba
  if ! pushd -- "$name_no_ext" >/dev/null; then
    echo "Hiba: nem lehet belépni a könyvtárba: $name_no_ext" >&2
    popd >/dev/null
    continue
  fi

  # Csendes kicsomagolás (-q). Ha sikertelen, nem törlünk.
  if unzip -q -- "../$zip_file"; then
    # Siker esetén töröljük az eredeti ZIP-et
    if ! rm -f -- "../$zip_file"; then
      echo "Figyelem: nem sikerült törölni a ZIP-et: ../$zip_file" >&2
    fi
  else
    echo "Hiba: sikertelen kicsomagolás: ../$zip_file" >&2
    # Nem törlünk semmit sikertelen kicsomagolás esetén
  fi

  # Vissza a ZIP helyére, majd az eredeti könyvtárba
  popd >/dev/null
  popd >/dev/null
done