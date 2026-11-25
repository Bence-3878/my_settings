#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$(uname -s)" in
    Linux*)   TARGET="$SCRIPT_DIR/os/linux.sh" ;;
    Darwin*)  TARGET="$SCRIPT_DIR/os/macos.sh" ;;
    FreeBSD*) TARGET="$SCRIPT_DIR/os/freebsd.sh" ;;
    *)
        echo "Nem támogatott rendszer: $(uname -s)" >&2
        exit 1
        ;;
esac

if [ ! -x "$TARGET" ]; then
    echo "Hiányzó vagy nem futtatható szkript: $TARGET" >&2
    exit 1
fi

exec "$TARGET" "$@"