#!/bin/bash

FILE=/run/kbd-backlight.level

for k in /sys/class/leds/*kbd_backlight*/brightness; do
    [ -e "$k" ] || continue
    cat "$k" > "$FILE" 2>/dev/null || true
    echo 0 > "$k"
done