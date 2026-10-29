#!/bin/bash
# ==============================================================================
# Raspberry Zero Dark Launcher: Pi Tin Handheld Edition
# Target: Raspberry Pi Zero 2W / Pi Tin (GPIOnext + ILI9340 SPI TFT + fbcp)
# Features:
#   - Freezes EmulationStation (SIGSTOP/SIGCONT) to prevent background input theft
#   - Hardware-level Fn + Start (BTN_TRIGGER_HAPPY2 + BTN_START) force-quit watchdog
#   - VideoCore IV DispmanX Layer 10000 & ALSA audio routing
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

WATCHDOG_PID=""

cleanup() {
    if [ -n "$WATCHDOG_PID" ] && kill -0 "$WATCHDOG_PID" 2>/dev/null; then
        kill "$WATCHDOG_PID" 2>/dev/null || true
    fi
    killall -CONT emulationstation emulationstatio 2>/dev/null || true
}

# Guarantee EmulationStation unfreezing and watchdog cleanup on exit or signal
trap cleanup EXIT INT TERM HUP

# Freeze EmulationStation to prevent background CPU usage and A-button interception
killall -STOP emulationstation emulationstatio 2>/dev/null || true

# Launch lightweight evdev watchdog for Fn (705) + Start (315) quit combo
python3 - << 'PYEOF' &
import sys, os, time, signal, subprocess
sys.stdout.reconfigure(line_buffering=True, errors='replace')
sys.stderr.reconfigure(line_buffering=True, errors='replace')

try:
    import evdev
except ImportError:
    sys.exit(0)

FN_CODE = 705     # BTN_TRIGGER_HAPPY2 (Pi Tin Fn button)
START_CODE = 315  # BTN_START

dev = None
for path in evdev.list_devices():
    try:
        d = evdev.InputDevice(path)
        if "GPIOnext" in d.name or "Joypad" in d.name:
            dev = d
            break
    except Exception:
        pass

if dev is None:
    sys.exit(0)

held = set()
try:
    for event in dev.read_loop():
        if event.type == evdev.ecodes.EV_KEY:
            if event.value in (1, 2):
                held.add(event.code)
            elif event.value == 0:
                held.discard(event.code)
            if FN_CODE in held and START_CODE in held:
                subprocess.run(
                    ["killall", "-TERM", "pd.armv6", "pd.armv7", "pd"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=5,
                )
                time.sleep(0.5)
                subprocess.run(
                    ["killall", "-9", "pd.armv6", "pd.armv7", "pd"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=5,
                )
                break
except Exception:
    pass
PYEOF
WATCHDOG_PID=$!

# VideoCore IV DispmanX & ALSA Audio configuration
export SDL_VIDEODRIVER=rpi
export SDL_RPI_VIDEO_LAYER=10000
export SDL_AUDIODRIVER=alsa

"$PD_BIN" --gl-version 2.0es "$@" > "$GAME_DIR/pd.log" 2>&1
