#!/bin/bash
# ==============================================================================
# Raspberry Zero Dark Launcher: Generic Raspberry Pi Zero 2W
# Target: Raspberry Pi Zero 2W / RetroPie
# ==============================================================================

# Locate game installation directory
if [ -d "/home/pi/perfectdark" ]; then
    GAME_DIR="/home/pi/perfectdark"
elif [ -d "$HOME/perfectdark" ]; then
    GAME_DIR="$HOME/perfectdark"
elif [ -f "$(dirname "$0")/pd.armv6" ] || [ -f "$(dirname "$0")/pd.armv7" ] || [ -f "$(dirname "$0")/pd" ]; then
    GAME_DIR="$(dirname "$0")"
else
    GAME_DIR="$(pwd)"
fi

cd "$GAME_DIR" || exit 1

# Determine executable binary name
if [ -x "./pd.armv6" ]; then
    PD_BIN="./pd.armv6"
elif [ -x "./pd.armv7" ]; then
    PD_BIN="./pd.armv7"
elif [ -x "./pd" ]; then
    PD_BIN="./pd"
else
    echo "Error: Perfect Dark executable (pd.armv6 / pd.armv7 / pd) not found in $GAME_DIR" >&2
    exit 1
fi

# Guarantee EmulationStation unfreezing on normal exit, error, or signal
trap 'killall -CONT emulationstation emulationstatio 2>/dev/null || true' EXIT INT TERM HUP

# Freeze EmulationStation if running so background menus do not consume CPU or input
killall -STOP emulationstation emulationstatio 2>/dev/null || true

# VideoCore IV DispmanX & ALSA Audio configuration
export SDL_VIDEODRIVER=rpi
export SDL_RPI_VIDEO_LAYER=10000
export SDL_AUDIODRIVER=alsa

"$PD_BIN" --gl-version 2.0es "$@" > "$GAME_DIR/pd.log" 2>&1

# Resume EmulationStation upon exit
killall -CONT emulationstation emulationstatio 2>/dev/null || true
