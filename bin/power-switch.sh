#!/bin/bash

#
# Universal AC/BATTERY power switch for Linux laptops
# CPU (AMD/Intel), NVIDIA, keyboard backlight
# Supports: Ubuntu 24.04+
#

LOG="/var/log/power-switch.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG"
}

# ---------- Detect AC / BATTERY ----------
AC=""
for x in /sys/class/power_supply/*/online; do
    [ -e "$x" ] && AC="$x" && break
done
[ -z "$AC" ] && exit 0

AC_STATE=$(cat "$AC")

# ---------- CPU info ----------
CPU_VENDOR=$(grep -m1 vendor_id /proc/cpuinfo | awk '{print $3}')

# ---------- NVIDIA ----------
NVIDIA=$(lspci -Dn | awk '/NVIDIA/{print $1}' | head -n1)

# ---------- Keyboard backlight ----------
KBD_BACKLIGHT=""
for kbd in /sys/class/leds/*kbd_backlight*/brightness; do
    [ -e "$kbd" ] && KBD_BACKLIGHT="$kbd" && break
done

set_kbd() {
    [ -n "$KBD_BACKLIGHT" ] && echo "$1" > "$KBD_BACKLIGHT" 2>/dev/null
}

# ---------- Functions ----------
disable_boost() {
    if [ "$CPU_VENDOR" = "AuthenticAMD" ] && [ -e /sys/devices/system/cpu/cpufreq/boost ]; then
        echo 0 > /sys/devices/system/cpu/cpufreq/boost
    elif [ "$CPU_VENDOR" = "GenuineIntel" ] && [ -e /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
        echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
    fi
}

enable_boost() {
    if [ "$CPU_VENDOR" = "AuthenticAMD" ] && [ -e /sys/devices/system/cpu/cpufreq/boost ]; then
        echo 1 > /sys/devices/system/cpu/cpufreq/boost
    elif [ "$CPU_VENDOR" = "GenuineIntel" ] && [ -e /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
        echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo
    fi
}

set_cpu_freq_battery() {
    # Calculate 60% of max frequency
    CPU_MAX=$(awk -F: '/cpu MHz/ {print int($2)}' /proc/cpuinfo | sort -nr | head -1)
    CPU_MAX_KHZ=$((CPU_MAX * 1000))
    LIMIT=$((CPU_MAX_KHZ * 60 / 100))
    cpupower frequency-set -g powersave
    cpupower frequency-set -u "$LIMIT"
}

set_cpu_freq_ac() {
    cpupower frequency-set -g performance
    # Do not limit max freq
}

# ---------- Main ----------
if [ "$AC_STATE" = "1" ]; then
    # ================= AC MODE =================
    log "AC → performance"

    powerprofilesctl set performance
    set_cpu_freq_ac
    enable_boost

    # NVIDIA ON
    [ -n "$NVIDIA" ] && echo on > /sys/bus/pci/devices/0000:$NVIDIA/power/control 2>/dev/null

    # Keyboard backlight ON (max)
    set_kbd 1
else
    # ================= BATTERY MODE =================
    log "BATTERY → power-saver + keyboard off"

    powerprofilesctl set power-saver
    disable_boost
    set_cpu_freq_battery

    # NVIDIA OFF
    [ -n "$NVIDIA" ] && echo auto > /sys/bus/pci/devices/0000:$NVIDIA/power/control 2>/dev/null

    # Keyboard backlight OFF (save brightness)
    FILE=/run/kbd-backlight.level
    [ -n "$KBD_BACKLIGHT" ] && cat "$KBD_BACKLIGHT" > "$FILE" 2>/dev/null || true
    set_kbd 0
fi