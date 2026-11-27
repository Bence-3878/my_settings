#!/usr/bin/env bats

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    unset ZSH ZSH_CUSTOM
    mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

create_temp_repo() {
    local dest="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$dest/os" "$dest/scripts" "$dest/config/micro" "$dest/zsh/themes" "$dest/src" "$dest/bin"
    cp "$REPO_ROOT/install.sh" "$REPO_ROOT/bootstrap.sh" "$dest/"
    cp "$REPO_ROOT/os/"*.sh "$dest/os/"
    cp "$REPO_ROOT/scripts/"*.sh "$dest/scripts/"
    cp "$REPO_ROOT/config/fastfetch.jsonc" "$REPO_ROOT/config/neofetch.conf" "$REPO_ROOT/config/tmux.conf" "$REPO_ROOT/config/terminator.conf" "$REPO_ROOT/config/ddterm.dconf" "$dest/config/"
    cp "$REPO_ROOT/zsh/zshrc" "$REPO_ROOT/zsh/aliases.zsh" "$dest/zsh/"
    cp "$REPO_ROOT/zsh/themes/my.zsh-theme" "$dest/zsh/themes/"
    cp "$REPO_ROOT/src/error_teszt.c" "$dest/src/"
    cp "$REPO_ROOT/bin/unzip.sh" "$dest/bin/"
    chmod +x "$dest/install.sh" "$dest/bootstrap.sh" "$dest/os/"*.sh "$dest/scripts/"*.sh "$dest/bin/unzip.sh"
    echo "$dest"
}

@test "install.sh hibával áll le ismeretlen OS esetén" {
    printf '#!/bin/sh\necho "UnknownOS"\n' > "$BATS_TEST_TMPDIR/bin/uname"
    chmod +x "$BATS_TEST_TMPDIR/bin/uname"

    run "$REPO_ROOT/install.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Nem támogatott rendszer"* ]]
}

@test "install.sh Darwin esetén az os/macos.sh szkriptet futtatja" {
    printf '#!/bin/sh\necho "Darwin"\n' > "$BATS_TEST_TMPDIR/bin/uname"
    chmod +x "$BATS_TEST_TMPDIR/bin/uname"

    run "$REPO_ROOT/install.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Darwin telepítő még nincs implementálva"* ]]
}

@test "install.sh FreeBSD esetén az os/freebsd.sh szkriptet futtatja" {
    printf '#!/bin/sh\necho "FreeBSD"\n' > "$BATS_TEST_TMPDIR/bin/uname"
    chmod +x "$BATS_TEST_TMPDIR/bin/uname"

    run "$REPO_ROOT/install.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"FreeBSD telepítő még nincs implementálva"* ]]
}

@test "install.sh hibával áll le, ha a cél szkript nem futtatható" {
    local tmp_repo
    tmp_repo="$(create_temp_repo)"
    chmod -x "$tmp_repo/os/freebsd.sh"

    printf '#!/bin/sh\necho "FreeBSD"\n' > "$BATS_TEST_TMPDIR/bin/uname"
    chmod +x "$BATS_TEST_TMPDIR/bin/uname"

    run "$tmp_repo/install.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Hiányzó vagy nem futtatható szkript"* ]]
}

@test "install.sh Linux esetén továbbadja az argumentumokat az os/linux.sh-nak" {
    local tmp_repo
    tmp_repo="$(create_temp_repo)"
    printf '#!/usr/bin/env bash\necho "ARGS:$*"\n' > "$tmp_repo/os/linux.sh"
    chmod +x "$tmp_repo/os/linux.sh"

    printf '#!/bin/sh\necho "Linux"\n' > "$BATS_TEST_TMPDIR/bin/uname"
    chmod +x "$BATS_TEST_TMPDIR/bin/uname"

    run "$tmp_repo/install.sh" --server

    [ "$status" -eq 0 ]
    [ "$output" = "ARGS:--server" ]
}

@test "os/linux.sh hibával áll le érvénytelen profil kapcsoló esetén" {
    run "$REPO_ROOT/os/linux.sh" --invalid

    [ "$status" -eq 1 ]
    [[ "$output" == *"Használat:"* ]]
}

@test "os/linux.sh hibával áll le ismeretlen csomagkezelő esetén" {
    local isolated_bin="$BATS_TEST_TMPDIR/isolated_bin"
    mkdir -p "$isolated_bin"
    for cmd in bash dirname cd pwd cat echo grep rm mkdir chmod; do
        local p
        p="$(command -v "$cmd")"
        ln -sf "$p" "$isolated_bin/$cmd"
    done

    PATH="$isolated_bin" run /bin/bash "$REPO_ROOT/os/linux.sh" --server

    [ "$status" -eq 1 ]
    [[ "$output" == *"Nem támogatott csomagkezelő"* ]]
}

@test "os/linux.sh nem-interaktív módban DISPLAY nélkül server profilt választ és lefuttatja a teljes folyamatot" {
    local tmp_repo
    tmp_repo="$(create_temp_repo)"
    local log_file="$BATS_TEST_TMPDIR/calls.log"

    # Mock parancsok a teljes telepítéshez hálózat és root nélkül
    cat << EOF > "$BATS_TEST_TMPDIR/bin/sudo"
#!/usr/bin/env bash
echo "sudo \$*" >> "$log_file"
exec env "\$@"
EOF
    cat << EOF > "$BATS_TEST_TMPDIR/bin/apt"
#!/usr/bin/env bash
echo "apt \$*" >> "$log_file"
exit 0
EOF
    cat << EOF > "$BATS_TEST_TMPDIR/bin/curl"
#!/usr/bin/env bash
echo "curl \$*" >> "$log_file"
echo "echo OMZ_INSTALLER"
EOF
    cat << EOF > "$BATS_TEST_TMPDIR/bin/git"
#!/usr/bin/env bash
echo "git \$*" >> "$log_file"
# A legutolsó argumentum a célmappa
dest="\${@: -1}"
mkdir -p "\$dest"
EOF
    cat << EOF > "$BATS_TEST_TMPDIR/bin/chsh"
#!/usr/bin/env bash
echo "chsh \$*" >> "$log_file"
exit 0
EOF
    cat << EOF > "$BATS_TEST_TMPDIR/bin/tldr"
#!/usr/bin/env bash
echo "tldr \$*" >> "$log_file"
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/"*

    DISPLAY="" WAYLAND_DISPLAY="" run "$tmp_repo/os/linux.sh" < /dev/null

    [ "$status" -eq 0 ]
    [[ "$output" == *"Kiválasztott profil: server"* ]]
    [[ "$output" == *"Kész (server profil)!"* ]]
    # Oh My Zsh telepítő lefutott (mert link_configs.sh nem hozta létre előtte a ~/.oh-my-zsh-t!)
    grep -q "curl .*ohmyzsh" "$log_file"
    # Server csomag (ufw) telepítve, desktop csomag (gimp/terminator) nem
    grep -q "apt install -y ufw" "$log_file"
    ! grep -q "apt install -y terminator" "$log_file"
    # Symlinkek és binárisok elkészültek
    [ -L "$HOME/.zshrc" ]
    [ -x "$HOME/bin/error_teszt" ]
    grep -q 'export MY_SETTINGS_PROFILE="server"' "$HOME/.my_settings_env"
}

@test "os/linux.sh jelentést ad a sikertelen csomagokról és 0-val lép ki" {
    local tmp_repo
    tmp_repo="$(create_temp_repo)"
    local clean_bin="$BATS_TEST_TMPDIR/clean_bin"
    mkdir -p "$clean_bin"
    for cmd in bash sh env dirname basename cd pwd ls mkdir rm mv ln cp cat grep echo id; do
        ln -sf "$(command -v "$cmd")" "$clean_bin/$cmd"
    done

    printf '#!/usr/bin/env bash\nexec env "$@"\n' > "$BATS_TEST_TMPDIR/bin/sudo"
    # Minden apt install hibázik (kivéve update/upgrade)
    cat << 'EOF' > "$BATS_TEST_TMPDIR/bin/apt"
#!/usr/bin/env bash
if [[ "$1" == "install" ]]; then
  exit 1
fi
exit 0
EOF
    printf '#!/bin/sh\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/chsh"
    # Előre létrehozott OMZ és pluginok, hogy ne hívjon hálózatot
    mkdir -p "$HOME/.oh-my-zsh/custom/themes" "$HOME/.oh-my-zsh/custom/plugins"
    for p in zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search zsh-z you-should-use fzf-tab zsh-completions zsh-autopair; do
        mkdir -p "$HOME/.oh-my-zsh/custom/plugins/$p"
    done
    mkdir -p "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
    chmod +x "$BATS_TEST_TMPDIR/bin/"*

    DISPLAY="" WAYLAND_DISPLAY="" PATH="$BATS_TEST_TMPDIR/bin:$clean_bin" \
        run "$tmp_repo/os/linux.sh" --server < /dev/null

    [ "$status" -eq 0 ]
    [[ "$output" == *"Nem települt:"* ]]
    [[ "$output" == *"ufw"* ]]
}

@test "os/linux.sh --desktop X11-gyel telepíti az asztali, X11 és flatpak csomagokat" {
    local tmp_repo
    tmp_repo="$(create_temp_repo)"
    local log_file="$BATS_TEST_TMPDIR/desktop.log"

    cat << EOF > "$BATS_TEST_TMPDIR/bin/sudo"
#!/usr/bin/env bash
exec env "\$@"
EOF
    cat << EOF > "$BATS_TEST_TMPDIR/bin/apt"
#!/usr/bin/env bash
echo "apt \$*" >> "$log_file"
exit 0
EOF
    cat << EOF > "$BATS_TEST_TMPDIR/bin/flatpak"
#!/usr/bin/env bash
echo "flatpak \$*" >> "$log_file"
exit 0
EOF
    for extra in espanso uex lazygit antigravity chsh tldr; do
        printf '#!/bin/sh\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/$extra"
    done
    mkdir -p "$HOME/.local/share/fonts/JetBrainsMono"
    touch "$HOME/.local/share/fonts/JetBrainsMono/JetBrainsMono.ttf"
    mkdir -p "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
    for p in zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search zsh-z you-should-use fzf-tab zsh-completions zsh-autopair; do
        mkdir -p "$HOME/.oh-my-zsh/custom/plugins/$p"
    done
    chmod +x "$BATS_TEST_TMPDIR/bin/"*

    XDG_SESSION_TYPE="x11" run "$tmp_repo/os/linux.sh" --desktop < /dev/null

    [ "$status" -eq 0 ]
    [[ "$output" == *"Kiválasztott profil: desktop"* ]]
    grep -q "apt install -y terminator" "$log_file"
    grep -q "apt install -y numlockx" "$log_file"
    grep -q "flatpak install -y flathub org.gimp.GIMP org.remmina.Remmina" "$log_file"
    [ -L "$HOME/.config/terminator/config" ]
    grep -q 'export MY_SETTINGS_PROFILE="desktop"' "$HOME/.my_settings_env"
}

@test "bootstrap.sh frissíti a meglévő repót és továbbadja a kapcsolókat az install.sh-nak" {
    mkdir -p "$HOME/my_settings/.git"
    printf '#!/usr/bin/env bash\necho "INSTALL:$*"\n' > "$HOME/my_settings/install.sh"
    chmod +x "$HOME/my_settings/install.sh"

    local git_log="$BATS_TEST_TMPDIR/git.log"
    cat << EOF > "$BATS_TEST_TMPDIR/bin/git"
#!/usr/bin/env bash
echo "git \$*" >> "$git_log"
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/git"

    run "$REPO_ROOT/bootstrap.sh" --server

    [ "$status" -eq 0 ]
    grep -q "pull --ff-only" "$git_log"
    [[ "$output" == *"INSTALL:--server"* ]]
}

@test "bootstrap.sh klónozza a repót, ha még nem létezik" {
    local git_log="$BATS_TEST_TMPDIR/git.log"
    cat << EOF > "$BATS_TEST_TMPDIR/bin/git"
#!/usr/bin/env bash
echo "git \$*" >> "$git_log"
if [[ "\$1" == "clone" ]]; then
  mkdir -p "\$3"
  printf '#!/usr/bin/env bash\necho "CLONED_INSTALL:\$*"\n' > "\$3/install.sh"
  chmod +x "\$3/install.sh"
fi
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/git"

    run "$REPO_ROOT/bootstrap.sh" --desktop

    [ "$status" -eq 0 ]
    grep -q "clone .*my_settings" "$git_log"
    [[ "$output" == *"CLONED_INSTALL:--desktop"* ]]
}

@test "bootstrap.sh hibával áll le, ha nincs git és csomagkezelő sem" {
    local isolated_bin="$BATS_TEST_TMPDIR/isolated_bin"
    mkdir -p "$isolated_bin"
    for cmd in bash echo; do
        ln -sf "$(command -v "$cmd")" "$isolated_bin/$cmd"
    done

    PATH="$isolated_bin" run /bin/bash "$REPO_ROOT/bootstrap.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Telepítsd a git-et manuálisan"* ]]
}

@test "setup_micro.sh létrehozza a settings.json szimlinket" {
    local tmp_repo
    tmp_repo="$(create_temp_repo)"
    printf '#!/bin/sh\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/micro"
    chmod +x "$BATS_TEST_TMPDIR/bin/micro"

    run "$tmp_repo/scripts/setup_micro.sh"

    [ "$status" -eq 0 ]
    [ -L "$HOME/.config/micro/settings.json" ]
}
