#!/bin/bash

AC=""

for x in /sys/class/power_supply/*/online; do
    [ -e "$x" ] && AC="$x" && break
done

[ "$(cat "$AC" 2>/dev/null)" = "1" ] || exit 0

LEVEL=$(cat /run/kbd-backlight.level 2>/dev/null || echo 1)

for k in /sys/class/leds/*kbd_backlight*/brightness; do
    [ -e "$k" ] || continue
    echo "$LEVEL" > "$k"
done

systemctl restart kbd-backlight-off.timer