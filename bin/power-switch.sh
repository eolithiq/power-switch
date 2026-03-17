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

die() {
    log "ERROR: $1"
    exit 1
}

# ---------- Root check ----------
[ "$(id -u)" -eq 0 ] || die "Must run as root"

# ---------- Detect AC / BATTERY ----------
# Prefer dedicated AC adapter over USB-C PD sources
AC=""
for x in /sys/class/power_supply/AC*/online \
          /sys/class/power_supply/ADP*/online \
          /sys/class/power_supply/*/online; do
    [ -e "$x" ] && AC="$x" && break
done
[ -z "$AC" ] && { log "No power supply found"; exit 0; }

AC_STATE=$(cat "$AC")
log "Power event: $([ "$AC_STATE" = "1" ] && echo "AC plugged" || echo "Battery") [${AC}]"

# ---------- CPU info ----------
CPU_VENDOR=$(grep -m1 vendor_id /proc/cpuinfo | awk '{print $3}')
CPU_COUNT=$(nproc)

# ---------- NVIDIA ----------
# lspci -D outputs full address like 0000:01:00.0 — use it directly (no extra "0000:")
NVIDIA=$(lspci -Dn 2>/dev/null | awk '/NVIDIA/{print $1}' | head -n1)

# ---------- Backlight ----------
BACKLIGHT_PATH=$(ls -d /sys/class/backlight/*/ 2>/dev/null | head -n1)
if [ -n "$BACKLIGHT_PATH" ]; then
    BRIGHTNESS_MAX=$(cat "${BACKLIGHT_PATH}max_brightness")
else
    BRIGHTNESS_MAX=0
fi

set_brightness() {
    local val="$1"
    [ -n "$BACKLIGHT_PATH" ] && [ "$BRIGHTNESS_MAX" -gt 0 ] && \
        echo "$val" > "${BACKLIGHT_PATH}brightness" 2>/dev/null || true
}

# ---------- CPU boost ----------
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

# ---------- CPU frequency ----------
set_cpu_freq_battery() {
    # Use hardware max from cpufreq — /proc/cpuinfo reports *current* MHz, not max
    local max_khz
    max_khz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo 0)

    if command -v cpupower >/dev/null 2>&1; then
        cpupower frequency-set -g powersave 2>/dev/null || true
        if [ "$max_khz" -gt 0 ]; then
            local limit=$(( max_khz * 60 / 100 ))
            cpupower frequency-set -u "${limit}KHz" 2>/dev/null || true
        fi
    fi
}

set_cpu_freq_ac() {
    if command -v cpupower >/dev/null 2>&1; then
        cpupower frequency-set -g performance 2>/dev/null || true
        # Lift any upper limit — restore hardware max
        local max_khz
        max_khz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo 0)
        [ "$max_khz" -gt 0 ] && \
            cpupower frequency-set -u "${max_khz}KHz" 2>/dev/null || true
    fi
}

# ---------- NVIDIA power ----------
set_nvidia() {
    local mode="$1"  # "on" or "auto"
    [ -z "$NVIDIA" ] && return
    local pci_path="/sys/bus/pci/devices/${NVIDIA}/power/control"
    if [ -e "$pci_path" ]; then
        echo "$mode" > "$pci_path" 2>/dev/null || true
        log "NVIDIA ${NVIDIA}: power/control -> ${mode}"
    fi
}

# ---------- Main ----------
if [ "$AC_STATE" = "1" ]; then
    # ================= AC MODE =================
    log "Applying: performance"

    command -v powerprofilesctl >/dev/null 2>&1 && \
        powerprofilesctl set performance 2>/dev/null || true

    set_cpu_freq_ac
    enable_boost
    set_brightness "$BRIGHTNESS_MAX"
    set_nvidia "on"

    log "Done: AC/performance (CPU=$CPU_VENDOR x$CPU_COUNT, NVIDIA=${NVIDIA:-none})"
else
    # ================= BATTERY MODE =================
    log "Applying: power-saver"

    command -v powerprofilesctl >/dev/null 2>&1 && \
        powerprofilesctl set power-saver 2>/dev/null || true

    disable_boost
    set_cpu_freq_battery
    set_brightness $(( BRIGHTNESS_MAX * 60 / 100 ))
    set_nvidia "auto"

    log "Done: battery/power-saver (CPU=$CPU_VENDOR x$CPU_COUNT, NVIDIA=${NVIDIA:-none})"
fi
