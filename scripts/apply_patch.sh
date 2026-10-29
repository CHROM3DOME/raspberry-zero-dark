#!/bin/bash
# ==============================================================================
# Raspberry Zero Dark - Patch & Configuration Helper
# Applies either the Generic Raspberry Pi Zero 2W or Pi Tin Handheld patch
# against a clean fgsfdsfgs/perfect_dark (`port` branch, commit 32a1cb9f2) tree.
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

VARIANT="${1:-}"
TARGET_REPO="${2:-}"

usage() {
    echo "Usage: $0 <generic|pitin> </path/to/perfect_dark_repo> [runtime_dir]"
    echo ""
    echo "Variants:"
    echo "  generic  - Standard Raspberry Pi Zero 2W patch & config (HDMI/DPI, USB/BT gamepad or KB/M)"
    echo "  pitin    - Pi Tin handheld patch & config (GPIOnext controls, menu mouse-lockout, Fn+Start exit)"
    echo ""
    echo "Example:"
    echo "  $0 pitin ~/perfect_dark ~/perfectdark"
    exit 1
}

if [ -z "$VARIANT" ] || [ -z "$TARGET_REPO" ]; then
    usage
fi

case "$VARIANT" in
    generic)
        PATCH_FILE="$RELEASE_DIR/patches/0001-perfect-dark-rpi-zero2w-generic.patch"
        INI_FILE="$RELEASE_DIR/config/pd.ini.generic"
        LAUNCHER_FILE="$RELEASE_DIR/scripts/launchers/Perfect Dark (Generic).sh"
        ;;
    pitin|pi-tin)
        PATCH_FILE="$RELEASE_DIR/patches/0001-perfect-dark-rpi-zero2w-pi-tin.patch"
        INI_FILE="$RELEASE_DIR/config/pd.ini.pitin"
        LAUNCHER_FILE="$RELEASE_DIR/scripts/launchers/Perfect Dark (Pi Tin).sh"
        ;;
    *)
        echo "Error: Unknown variant '$VARIANT'. Choose 'generic' or 'pitin'." >&2
        usage
        ;;
esac

if [ ! -e "$TARGET_REPO/.git" ]; then
    echo "Error: '$TARGET_REPO' does not appear to be a git repository." >&2
    exit 1
fi

echo "[*] Checking patch applicability on $TARGET_REPO ($VARIANT)..."
git -C "$TARGET_REPO" apply --check "$PATCH_FILE"

echo "[*] Applying $VARIANT patch..."
git -C "$TARGET_REPO" apply "$PATCH_FILE"
echo "[+] Source patch applied cleanly."

RUNTIME_DIR="${3:-}"
if [ -n "$RUNTIME_DIR" ]; then
    mkdir -p "$RUNTIME_DIR/data"
    cp "$INI_FILE" "$RUNTIME_DIR/pd.ini"
    cp "$RELEASE_DIR/config/gamecontrollerdb.txt" "$RUNTIME_DIR/gamecontrollerdb.txt"
    cp "$LAUNCHER_FILE" "$RUNTIME_DIR/perfectdark.sh"
    chmod +x "$RUNTIME_DIR/perfectdark.sh"
    echo "[+] Installed pd.ini, gamecontrollerdb.txt, and perfectdark.sh to $RUNTIME_DIR"
fi

echo ""
echo "Next steps to compile on Raspberry Pi Zero 2W:"
echo "  cd "$TARGET_REPO" && mkdir -p build && cd build"
echo "  cmake .. -DCMAKE_BUILD_TYPE=Release"
echo "  make -j2"
