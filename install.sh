#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

is_wsl() {
    [ -n "${WSL_DISTRO_NAME:-}" ] || [ -n "${WSL_INTEROP:-}" ] || grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}

case "$(uname -s)" in
    Linux*)
        if is_wsl; then
            TARGET="$SCRIPT_DIR/os/wsl.sh"
        else
            TARGET="$SCRIPT_DIR/os/linux.sh"
        fi
        ;;
    Darwin*)  TARGET="$SCRIPT_DIR/os/macos.sh" ;;
    FreeBSD*) TARGET="$SCRIPT_DIR/os/freebsd.sh" ;;
    *)
        echo "Nem támogatott rendszer: $(uname -s)" >&2
        exit 1
        ;;
esac

if [ ! -f "$TARGET" ]; then
    echo "Hiányzó szkript: $TARGET" >&2
    exit 1
fi

if [ -x "$TARGET" ]; then
    exec "$TARGET" "$@"
elif head -n 1 "$TARGET" | grep -q 'bash'; then
    exec bash "$TARGET" "$@"
else
    exec sh "$TARGET" "$@"
fi