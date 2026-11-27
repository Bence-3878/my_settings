#!/usr/bin/env bats

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

# --- scripts/build_bin.sh & src/error_teszt.c ---

@test "build_bin.sh lefordítja az error_teszt.c-t és a bináris helyesen működik" {
    run "$REPO_ROOT/scripts/build_bin.sh"

    [ "$status" -eq 0 ]
    [ -x "$HOME/bin/error_teszt" ]

    run "$HOME/bin/error_teszt"
    [ "$status" -eq 2 ]

    run "$HOME/bin/error_teszt" "42"
    [ "$status" -eq 42 ]

    run "$HOME/bin/error_teszt" "bc"
    [ "$status" -eq 12 ]

    run "$HOME/bin/error_teszt" "CD"
    [ "$status" -eq 23 ]
}

@test "build_bin.sh kihagyja az újrafordítást, ha a bináris frissebb, és újrafordít változáskor" {
    local tmp_repo="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$tmp_repo/src" "$tmp_repo/scripts"
    cp "$REPO_ROOT/scripts/build_bin.sh" "$tmp_repo/scripts/"
    cp "$REPO_ROOT/src/error_teszt.c" "$tmp_repo/src/"
    chmod +x "$tmp_repo/scripts/build_bin.sh"

    run "$tmp_repo/scripts/build_bin.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Fordítás: error_teszt"* ]]

    # Második futtatás változás nélkül -> nincs fordítás
    run "$tmp_repo/scripts/build_bin.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Fordítás: error_teszt"* ]]

    # Forrásfájl frissítése jövőbeli időbélyeggel -> újrafordít
    touch -d "+10 seconds" "$tmp_repo/src/error_teszt.c"
    run "$tmp_repo/scripts/build_bin.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Fordítás: error_teszt"* ]]
}

@test "build_bin.sh figyelmeztetéssel, 0-val lép ki, ha nincs C fordító" {
    local clean_bin="$BATS_TEST_TMPDIR/clean_bin"
    mkdir -p "$clean_bin"
    for cmd in bash dirname mkdir basename; do
        ln -sf "$(command -v "$cmd")" "$clean_bin/$cmd"
    done

    PATH="$clean_bin" run /bin/bash "$REPO_ROOT/scripts/build_bin.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"nincs C fordító"* ]]
}

# --- bin/unzip.sh ---

@test "unzip.sh argumentum nélkül használati üzenettel és 1-es kóddal lép ki" {
    run "$REPO_ROOT/bin/unzip.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Használat:"* ]]
}

@test "unzip.sh 2-es kóddal lép ki, ha az unzip parancs nem elérhető" {
    local clean_bin="$BATS_TEST_TMPDIR/clean_bin"
    mkdir -p "$clean_bin"
    for cmd in bash dirname basename; do
        ln -sf "$(command -v "$cmd")" "$clean_bin/$cmd"
    done

    PATH="$clean_bin" run /bin/bash "$REPO_ROOT/bin/unzip.sh" "test.zip"

    [ "$status" -eq 2 ]
    [[ "$output" == *"nincs telepítve"* ]]
}

@test "unzip.sh kihagyja a nem-zip fájlokat és nem hoz létre üres mappát nem létező zip-hez" {
    local work="$BATS_TEST_TMPDIR/work"
    mkdir -p "$work"
    echo "szöveg" > "$work/notes.txt"

    run "$REPO_ROOT/bin/unzip.sh" "$work/notes.txt" "$work/hianyzo.zip"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Kihagyva (nem ZIP)"* ]]
    [[ "$output" == *"a fájl nem létezik"* ]]
    [ -f "$work/notes.txt" ]
    [ ! -d "$work/hianyzo" ]
}

@test "unzip.sh kicsomagolja a .zip és .ZIP fájlokat, megőrzi a meglévő fájlt (-n), és törli az archívumot" {
    local work="$BATS_TEST_TMPDIR/work"
    mkdir -p "$work/sub" "$work/src_files"
    echo "uj tartalom" > "$work/src_files/hello.txt"
    echo "meglevo uj" > "$work/src_files/keep.txt"

    (cd "$work/src_files" && zip -q "$work/sub/archive one.ZIP" hello.txt keep.txt)

    # Előre létező keep.txt a célmappában ne íródjon felül (-n)
    mkdir -p "$work/sub/archive one"
    echo "regi vedett" > "$work/sub/archive one/keep.txt"

    run "$REPO_ROOT/bin/unzip.sh" "$work/sub/archive one.ZIP"

    [ "$status" -eq 0 ]
    [ ! -e "$work/sub/archive one.ZIP" ]
    [ -f "$work/sub/archive one/hello.txt" ]
    [ "$(cat "$work/sub/archive one/hello.txt")" = "uj tartalom" ]
    [ "$(cat "$work/sub/archive one/keep.txt")" = "regi vedett" ]
}

@test "unzip.sh sérült zip esetén hibát ír és nem törli a zip fájlt" {
    local work="$BATS_TEST_TMPDIR/work"
    mkdir -p "$work"
    echo "nem igazi zip" > "$work/bad.zip"

    run "$REPO_ROOT/bin/unzip.sh" "$work/bad.zip"

    [ "$status" -eq 0 ]
    [[ "$output" == *"sikertelen kicsomagolás"* ]]
    [ -f "$work/bad.zip" ]
}
