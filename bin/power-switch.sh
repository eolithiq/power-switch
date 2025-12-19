#!/bin/bash

#
# Universal AC / BATTERY power switch for Linux laptops
# CPU (AMD/Intel), NVIDIA
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

# Max brightness (for future use)
BRIGHTNESS_MAX=$(cat /sys/class/backlight/amdgpu_bl1/max_brightness)

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
    log "AC - performance"

    powerprofilesctl set performance
    set_cpu_freq_ac
    enable_boost

    echo $BRIGHTNESS_MAX > /sys/class/backlight/*/brightness 2>/dev/null

    # NVIDIA ON    
    [ -n "$NVIDIA" ] && echo on > /sys/bus/pci/devices/0000:$NVIDIA/power/control 2>/dev/null
    prime-select nvidia >/dev/null 2>&1
else
    # ================= BATTERY MODE =================
    log "BATTERY - power-saver"

    powerprofilesctl set power-saver
    disable_boost
    set_cpu_freq_battery

    echo $((BRIGHTNESS_MAX * 60 / 100)) > /sys/class/backlight/*/brightness 2>/dev/null

    # NVIDIA OFF
    [ -n "$NVIDIA" ] && echo auto > /sys/bus/pci/devices/0000:$NVIDIA/power/control 2>/dev/null    
fi