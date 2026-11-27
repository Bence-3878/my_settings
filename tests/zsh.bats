#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "zsh konfigurációs fájlok szintaxisa hibátlan (zsh -n)" {
    run zsh -n "$REPO_ROOT/zsh/zshrc" "$REPO_ROOT/zsh/aliases.zsh" "$REPO_ROOT/zsh/themes/my.zsh-theme"

    [ "$status" -eq 0 ]
}

@test "aliases.zsh mkcd létrehozza a mappát és belép, üres paraméternél 1-gyel kilép" {
    local target="$BATS_TEST_TMPDIR/a/b/c"

    run zsh -c "source '$REPO_ROOT/zsh/aliases.zsh' && mkcd '$target' && pwd"

    [ "$status" -eq 0 ]
    [ "$output" = "$target" ]
    [ -d "$target" ]

    run zsh -c "source '$REPO_ROOT/zsh/aliases.zsh' && mkcd"
    [ "$status" -eq 1 ]
}

@test "my.zsh-theme prompt_virtualenv kezeli a .venv szülő mappát és a conda-t" {
    run zsh -c "
        source '$REPO_ROOT/zsh/themes/my.zsh-theme'
        VIRTUAL_ENV='/tmp/my_project/.venv'
        CONDA_DEFAULT_ENV=''
        prompt_virtualenv
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"py:my_project"* ]]

    run zsh -c "
        source '$REPO_ROOT/zsh/themes/my.zsh-theme'
        VIRTUAL_ENV=''
        CONDA_DEFAULT_ENV='ml-env'
        prompt_virtualenv
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"py:ml-env"* ]]
}

@test "my.zsh-theme build_rprompt jelzi a hibakódot és a futási időt" {
    run zsh -c "
        source '$REPO_ROOT/zsh/themes/my.zsh-theme'
        _MY_CMD_ELAPSED=125
        build_rprompt 42
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"✘ 42"* ]]
    [[ "$output" == *"⏱ 2m 5s"* ]]
}
