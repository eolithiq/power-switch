#!/bin/bash

#
# Keyboard backlight daemon
# AC / BATTERY aware, typing-only activation, auto-off after inactivity
#

LOG="/var/log/kbd-backlight-daemon.log"
TIMEOUT=120         # seconds of inactivity before backlight turns off
POLL_INTERVAL=2     # main loop poll interval (seconds)

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG"
}

# ---------- Persistent state (survives reboots) ----------
STATE_DIR=/var/lib/kbd-backlight
LAST_LEVEL_FILE=$STATE_DIR/kbd-backlight-level
mkdir -p "$STATE_DIR"

# ---------- Runtime state ----------
LAST_INPUT_FILE=/run/kbd-backlight.last

# ---------- Keyboard backlight sysfs ----------
KBD_BACKLIGHT=$(ls /sys/class/leds/*kbd_backlight*/brightness 2>/dev/null | head -n1)
if [ -z "$KBD_BACKLIGHT" ]; then
    log "No keyboard backlight found — exiting"
    exit 0
fi

KBD_MAX=$(cat "$(dirname "$KBD_BACKLIGHT")/max_brightness" 2>/dev/null || echo 1)

# ---------- Init state files ----------
[ ! -f "$LAST_INPUT_FILE" ] && date +%s > "$LAST_INPUT_FILE"
[ ! -f "$LAST_LEVEL_FILE" ] && echo "$KBD_MAX" > "$LAST_LEVEL_FILE"

set_kbd() {
    echo "$1" > "$KBD_BACKLIGHT" 2>/dev/null || true
}

# Check if running on AC power
is_ac() {
    for f in /sys/class/power_supply/AC*/online \
              /sys/class/power_supply/ADP*/online \
              /sys/class/power_supply/*/online; do
        [ -e "$f" ] && [ "$(cat "$f" 2>/dev/null)" = "1" ] && return 0
    done
    return 1
}

# Called on each keypress event
on_keypress() {
    # On battery — keep backlight off
    if ! is_ac; then
        set_kbd 0
        return
    fi

    local current
    current=$(cat "$KBD_BACKLIGHT" 2>/dev/null || echo 0)

    # Save level only when backlight is actually on (avoids saving 0 after timeout)
    if [ "$current" -gt 0 ]; then
        echo "$current" > "$LAST_LEVEL_FILE"
    fi

    # Restore the saved brightness
    local saved
    saved=$(cat "$LAST_LEVEL_FILE" 2>/dev/null || echo "$KBD_MAX")
    [ "$saved" -le 0 ] && saved="$KBD_MAX"

    date +%s > "$LAST_INPUT_FILE"
    set_kbd "$saved"
}

# ---------- Find keyboard input device ----------
DEV=$(grep -i keyboard /proc/bus/input/devices -A5 \
    | grep Handlers | grep -o 'event[0-9]*' | head -n1)

if [ -z "$DEV" ]; then
    log "No keyboard input device found — exiting"
    exit 1
fi
DEV="/dev/input/$DEV"
log "Keyboard device: $DEV | KBD backlight: $KBD_BACKLIGHT (max=$KBD_MAX)"

# ---------- Dependency check ----------
if ! command -v evtest >/dev/null 2>&1; then
    log "evtest not found — install with: sudo apt install evtest"
    exit 1
fi

# ---------- Cleanup on exit ----------
cleanup() {
    log "Daemon stopping"
    set_kbd 0
    kill -- -$$ 2>/dev/null || true
}
trap cleanup EXIT TERM INT

# ---------- Keyboard listener (background) ----------
evtest "$DEV" 2>/dev/null | while IFS= read -r line; do
    if [[ "$line" == *"EV_KEY"* && "$line" == *"value 1"* ]]; then
        on_keypress
    fi
done &
EVTEST_PID=$!
log "evtest listener PID=$EVTEST_PID"

# ---------- Inactivity watcher (main loop) ----------
while true; do
    sleep "$POLL_INTERVAL"

    # Kill daemon if evtest died unexpectedly
    if ! kill -0 "$EVTEST_PID" 2>/dev/null; then
        log "evtest process died — restarting daemon"
        exit 1   # systemd Restart=always will bring us back
    fi

    NOW=$(date +%s)
    LAST=$(cat "$LAST_INPUT_FILE" 2>/dev/null || echo "$NOW")
    IDLE=$(( NOW - LAST ))

    if [ "$IDLE" -ge "$TIMEOUT" ]; then
        current=$(cat "$KBD_BACKLIGHT" 2>/dev/null || echo 0)
        if [ "$current" -gt 0 ]; then
            log "Inactivity timeout (${IDLE}s) — backlight off"
            set_kbd 0
        fi
    fi

    # On battery — always ensure backlight is off
    if ! is_ac; then
        current=$(cat "$KBD_BACKLIGHT" 2>/dev/null || echo 0)
        [ "$current" -gt 0 ] && set_kbd 0
    fi
done
