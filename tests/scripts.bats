#!/usr/bin/env bats

setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    unset ZSH ZSH_CUSTOM DBUS_SESSION_BUS_ADDRESS
    mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    # Izolált repó másolat a tesztekhez, hogy a munkakönyvtár ne módosuljon
    TMP_REPO="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$TMP_REPO/scripts" "$TMP_REPO/config/micro" "$TMP_REPO/zsh/themes"
    cp "$REPO_ROOT/scripts/"*.sh "$TMP_REPO/scripts/"
    cp "$REPO_ROOT/config/fastfetch.jsonc" "$REPO_ROOT/config/neofetch.conf" "$REPO_ROOT/config/tmux.conf" "$REPO_ROOT/config/terminator.conf" "$REPO_ROOT/config/ddterm.dconf" "$TMP_REPO/config/"
    cp "$REPO_ROOT/zsh/zshrc" "$TMP_REPO/zsh/"
    cp "$REPO_ROOT/zsh/themes/my.zsh-theme" "$TMP_REPO/zsh/themes/"
    chmod +x "$TMP_REPO/scripts/"*.sh
}

# --- link_configs.sh ---

@test "link_configs.sh biztonsági mentést készít a meglévő .zshrc-ről és létrehozza a symlinkeket" {
    echo "# regi zshrc" > "$HOME/.zshrc"

    run "$TMP_REPO/scripts/link_configs.sh" desktop

    [ "$status" -eq 0 ]
    [ -f "$HOME/.zshrc.bak" ]
    grep -q "# regi zshrc" "$HOME/.zshrc.bak"
    [ -L "$HOME/.zshrc" ]
    [ "$(readlink "$HOME/.zshrc")" = "$TMP_REPO/zsh/zshrc" ]
    [ -L "$HOME/.config/fastfetch/config.jsonc" ]
    [ -L "$HOME/.config/neofetch/config.conf" ]
    [ -L "$HOME/.tmux.conf" ]
    [ -L "$HOME/.config/terminator/config" ]
    [ -L "$HOME/.oh-my-zsh/custom/themes/my.zsh-theme" ]
    grep -q "export MY_SETTINGS_DIR=\"$TMP_REPO\"" "$HOME/.my_settings_env"
    grep -q 'export MY_SETTINGS_PROFILE="desktop"' "$HOME/.my_settings_env"
}

@test "link_configs.sh nem írja felül a .zshrc.bak-ot újrafuttatáskor, és server profilnál kihagyja a terminatort" {
    echo "# eredeti mentes" > "$HOME/.zshrc.bak"
    ln -sf "$TMP_REPO/zsh/zshrc" "$HOME/.zshrc"

    run "$TMP_REPO/scripts/link_configs.sh" server

    [ "$status" -eq 0 ]
    grep -q "# eredeti mentes" "$HOME/.zshrc.bak"
    [ ! -e "$HOME/.config/terminator/config" ]
    grep -q 'export MY_SETTINGS_PROFILE="server"' "$HOME/.my_settings_env"
}

@test "link_configs.sh betölti a ddterm.dconf fájlt desktop módban, ha van dconf és DBUS" {
    local dconf_log="$BATS_TEST_TMPDIR/dconf.log"
    cat << EOF > "$BATS_TEST_TMPDIR/bin/dconf"
#!/usr/bin/env bash
echo "dconf \$*" >> "$dconf_log"
cat > "$BATS_TEST_TMPDIR/dconf_input.txt"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/dconf"

    DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/fake-dbus" run "$TMP_REPO/scripts/link_configs.sh" desktop

    [ "$status" -eq 0 ]
    grep -q "dconf load /com/github/amezin/ddterm/" "$dconf_log"
    [ -s "$BATS_TEST_TMPDIR/dconf_input.txt" ]
}

# --- setup_micro.sh ---

@test "setup_micro.sh telepíti a hiányzó micro-t apt-get-tel és a hiányzó pluginokat" {
    local log_file="$BATS_TEST_TMPDIR/micro_calls.log"
    mkdir -p "$HOME/.config/micro/plug/fzf"

    cat << EOF > "$BATS_TEST_TMPDIR/bin/sudo"
#!/usr/bin/env bash
echo "sudo \$*" >> "$log_file"
exec "\$@"
EOF
    cat << EOF > "$BATS_TEST_TMPDIR/bin/apt-get"
#!/usr/bin/env bash
echo "apt-get \$*" >> "$log_file"
if [[ "\$*" == *"install -y micro"* ]]; then
  cat << 'INNER' > "$BATS_TEST_TMPDIR/bin/micro"
#!/usr/bin/env bash
echo "micro \$*" >> "$log_file"
INNER
  chmod +x "$BATS_TEST_TMPDIR/bin/micro"
fi
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/sudo" "$BATS_TEST_TMPDIR/bin/apt-get"

    # Izolált PATH, hogy a rendszerbeli /usr/bin/micro ne látszódjon
    local clean_bin="$BATS_TEST_TMPDIR/clean_bin"
    mkdir -p "$clean_bin"
    for cmd in bash sh dirname mkdir cat ln echo chmod; do
        ln -sf "$(command -v "$cmd")" "$clean_bin/$cmd"
    done

    PATH="$BATS_TEST_TMPDIR/bin:$clean_bin" run "$TMP_REPO/scripts/setup_micro.sh"

    [ "$status" -eq 0 ]
    grep -q "apt-get install -y micro" "$log_file"
    grep -q "micro -plugin install filemanager" "$log_file"
    ! grep -q "micro -plugin install fzf" "$log_file"
    [ -L "$HOME/.config/micro/settings.json" ]
    grep -q '"tabsize": 4' "$HOME/.config/micro/settings.json"
}

# --- setup_zsh.sh ---

@test "setup_zsh.sh telepíti az Oh My Zsh-t, klónozza a pluginokat és átállítja a shellt" {
    local log_file="$BATS_TEST_TMPDIR/zsh_calls.log"
    cat << EOF > "$BATS_TEST_TMPDIR/bin/curl"
#!/usr/bin/env bash
echo "curl \$*" >> "$log_file"
echo 'mkdir -p "\$HOME/.oh-my-zsh"'
EOF
    cat << EOF > "$BATS_TEST_TMPDIR/bin/git"
#!/usr/bin/env bash
echo "git \$*" >> "$log_file"
dest="\${@: -1}"
mkdir -p "\$dest"
EOF
    cat << EOF > "$BATS_TEST_TMPDIR/bin/zsh"
#!/usr/bin/env bash
exit 0
EOF
    cat << EOF > "$BATS_TEST_TMPDIR/bin/sudo"
#!/usr/bin/env bash
echo "sudo \$*" >> "$log_file"
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/"*

    SHELL="/bin/bash" run "$TMP_REPO/scripts/setup_zsh.sh"

    [ "$status" -eq 0 ]
    [ -d "$HOME/.oh-my-zsh" ]
    [ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]
    [ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]
    [ -d "$HOME/.oh-my-zsh/custom/plugins/fzf-tab" ]
    [ -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]
    grep -q "sudo chsh -s .*zsh" "$log_file"
}

@test "setup_zsh.sh átugorja a klónozást, ha minden mappa létezik" {
    local log_file="$BATS_TEST_TMPDIR/zsh_skip.log"
    mkdir -p "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
    for p in zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search zsh-z you-should-use fzf-tab zsh-completions zsh-autopair; do
        mkdir -p "$HOME/.oh-my-zsh/custom/plugins/$p"
    done

    printf '#!/usr/bin/env bash\necho "curl" >> "%s"\n' "$log_file" > "$BATS_TEST_TMPDIR/bin/curl"
    printf '#!/usr/bin/env bash\necho "git" >> "%s"\n' "$log_file" > "$BATS_TEST_TMPDIR/bin/git"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/zsh"
    chmod +x "$BATS_TEST_TMPDIR/bin/"*

    SHELL="$BATS_TEST_TMPDIR/bin/zsh" run "$TMP_REPO/scripts/setup_zsh.sh"

    [ "$status" -eq 0 ]
    [ ! -e "$log_file" ]
}

# --- setup_ssh.sh ---

@test "setup_ssh.sh hibával áll le érvénytelen mód esetén" {
    run "$TMP_REPO/scripts/setup_ssh.sh" invalid_mode

    [ "$status" -eq 1 ]
    [[ "$output" == *"Használat:"* ]]
}

@test "setup_ssh.sh client mód létrehozza a configokat és idempotensen kezeli az Include sort" {
    printf '#!/bin/sh\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/xauth"
    chmod +x "$BATS_TEST_TMPDIR/bin/xauth"
    mkdir -p "$HOME/.ssh"
    echo "Host mybox" > "$HOME/.ssh/config"

    run "$TMP_REPO/scripts/setup_ssh.sh" client
    [ "$status" -eq 0 ]

    # Második futtatás ne duplázza az Include sort
    run "$TMP_REPO/scripts/setup_ssh.sh" client
    [ "$status" -eq 0 ]

    [ -L "$HOME/.ssh/config.d/10-x11.conf" ]
    grep -q "ForwardX11 yes" "$HOME/.ssh/config.d/10-x11.conf"
    [ "$(grep -c '^Include config.d/\*\.conf' "$HOME/.ssh/config")" -eq 1 ]
    [ "$(stat -c '%a' "$HOME/.ssh")" = "700" ]
    [ "$(stat -c '%a' "$HOME/.ssh/config")" = "600" ]
}

@test "setup_ssh.sh server mód konfigurálja az sshd-t és újratölti a szolgáltatást" {
    local log_file="$BATS_TEST_TMPDIR/ssh_server.log"
    local fake_sshd_conf="$BATS_TEST_TMPDIR/sshd_config"
    touch "$fake_sshd_conf"

    printf '#!/bin/sh\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/sshd"
    printf '#!/bin/sh\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/xauth"
    cat << EOF > "$BATS_TEST_TMPDIR/bin/sudo"
#!/usr/bin/env bash
echo "sudo \$*" >> "$log_file"
case "\$1" in
  mkdir|sshd|systemctl) exit 0 ;;
  grep) shift; grep "\${@//\/etc\/ssh\/sshd_config/$fake_sshd_conf}" ;;
  tee)
    shift
    if [[ "\$1" == "-a" ]]; then
      cat >> "$fake_sshd_conf"
    else
      cat > "$BATS_TEST_TMPDIR/99-x11.conf"
    fi
    ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/"*

    run "$TMP_REPO/scripts/setup_ssh.sh" server

    [ "$status" -eq 0 ]
    grep -q "X11Forwarding yes" "$BATS_TEST_TMPDIR/99-x11.conf"
    grep -q '^Include /etc/ssh/sshd_config.d/\*\.conf' "$fake_sshd_conf"
    grep -q "sudo sshd -t" "$log_file"
    grep -q "sudo systemctl reload ssh" "$log_file"
}

# --- add_ssh_host.sh ---

@test "add_ssh_host.sh nem-interaktív módban azonnal 0-val kilép" {
    run bash -c "\"$TMP_REPO/scripts/add_ssh_host.sh\" < /dev/null"

    [ "$status" -eq 0 ]
    [ ! -d "$HOME/.ssh" ]
}

@test "add_ssh_host.sh interaktívan felvesz új hostot és elutasítja a duplikált nevet" {
    # PTY szimulálása util-linux script paranccsal
    local input_file="$BATS_TEST_TMPDIR/inputs.txt"
    printf 'i\nrpi\n192.168.1.50\npako\n2222\n~/.ssh/id_ed25519\ni\nrpi\nn\n' > "$input_file"

    run script -q -e -c "$TMP_REPO/scripts/add_ssh_host.sh" /dev/null < "$input_file"

    [ "$status" -eq 0 ]
    [ -f "$HOME/.ssh/config.d/99-local.conf" ]
    grep -q '^Include config.d/\*\.conf' "$HOME/.ssh/config"
    grep -q '^Host rpi$' "$HOME/.ssh/config.d/99-local.conf"
    grep -q 'HostName 192.168.1.50' "$HOME/.ssh/config.d/99-local.conf"
    grep -q 'User pako' "$HOME/.ssh/config.d/99-local.conf"
    grep -q 'Port 2222' "$HOME/.ssh/config.d/99-local.conf"
    grep -q 'IdentityFile ~/.ssh/id_ed25519' "$HOME/.ssh/config.d/99-local.conf"
    [[ "$output" == *"már létezik"* ]]
}
