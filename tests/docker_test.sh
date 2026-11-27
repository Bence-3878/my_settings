#!/usr/bin/env bash

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -n "${DOCKER_DISTRO:-}" ]]; then
    DISTROS=("$DOCKER_DISTRO")
else
    DISTROS=(
        "ubuntu:24.04"
        "debian:bookworm"
        "fedora:latest"
        "archlinux:latest"
    )
fi

FAILED=0

for distro in "${DISTROS[@]}"; do
    echo "==> Docker teszt indítása: $distro"
    LOG_FILE="$(mktemp)"

    docker run --rm \
        -e DEBIAN_FRONTEND=noninteractive \
        -v "$REPO_ROOT:/repo:ro" \
        "$distro" \
        sh -c '
            set -e
            # Alap Docker konténerekben nincs sudo, de rootként futunk
            if ! command -v sudo >/dev/null 2>&1; then
                printf "#!/bin/sh\nexec \"\$@\"\n" > /usr/local/bin/sudo
                chmod +x /usr/local/bin/sudo
            fi
            cp -a /repo /tmp/my_settings
            cd /tmp/my_settings
            ./install.sh ${1+"$@"}
        ' _ ${1+"$@"} > "$LOG_FILE" 2>&1

    EXIT_CODE=$?

    if [ "$EXIT_CODE" -ne 0 ]; then
        FAILED=1
        echo "[HIBA] $distro (kilépési kód: $EXIT_CODE)"
        tail -n 25 "$LOG_FILE"
        echo "----------------------------------------"
    else
        echo "[OK] $distro"
    fi

    rm -f "$LOG_FILE"
done

exit "$FAILED"