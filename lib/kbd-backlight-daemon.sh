#!/bin/bash

#
# Keyboard backlight daemon
# AC / BATTERY, typing only, delay off, restore brightness
#

set -euo pipefail

LOG="/var/log/kbd-backlight-daemon.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG"
}

TIMEOUT=120 # seconds

# Persistent state (SURVIVES restart)
STATE_DIR=/var/lib/kbd-backlight
LAST_LEVEL_FILE=$STATE_DIR/kbd-backlight-level

# Runtime state
LAST_INPUT_FILE=/run/kbd-backlight.last

mkdir -p "$STATE_DIR"

# Keyboard backlight sysfs
KBD_BACKLIGHT=$(ls /sys/class/leds/*kbd_backlight*/brightness 2>/dev/null | head -n1)
[ -z "$KBD_BACKLIGHT" ] && exit 0

# Init files
[ ! -f "$LAST_INPUT_FILE" ] && date +%s > "$LAST_INPUT_FILE"
[ ! -f "$LAST_LEVEL_FILE" ] && echo 1 > "$LAST_LEVEL_FILE"

set_kbd() {
    echo "$1" > "$KBD_BACKLIGHT"    
}

enable_backlight() {
    LAST_INPUT_LEVEL=$(cat /sys/class/leds/*kbd_backlight*/brightness)
    
    if [ "$LAST_INPUT_LEVEL" -gt 0 ]; then
        echo "$LAST_INPUT_LEVEL" > "$LAST_LEVEL_FILE"
    else
        echo 1 > "$LAST_LEVEL_FILE"
    fi
    
    date +%s > "$LAST_INPUT_FILE"
    set_kbd $(cat "$LAST_LEVEL_FILE")
}

# Find keyboard device
DEV=$(grep -i keyboard /proc/bus/input/devices -A5 \
    | grep Handlers | grep -o 'event[0-9]*' | head -n1)

[ -z "$DEV" ] && exit 1
DEV="/dev/input/$DEV"
log "Keyboard device - ${DEV}"

# evtest check
command -v evtest >/dev/null 2>&1 || { echo "Install evtest: sudo apt install evtest"; exit 1; }

# Keyboard listener (NO pipe, NO subshell)
evtest "$DEV" 2>/dev/null | while read -r line; do
    if [[ "$line" == *"EV_KEY"* || "$line" == *"KEY_UP"* ]]; then
        enable_backlight
    fi
done & 

# Timeout watcher (main process)
while true; do
    sleep 1
    NOW=$(date +%s)
    LAST=$(cat "$LAST_INPUT_FILE")
    
    if [ $((NOW - LAST)) -ge "$TIMEOUT" ]; then
        set_kbd 0
    fi
done