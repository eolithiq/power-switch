#!/bin/bash

set -e

NONE='\033[00m'
RED='\033[01;31m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
PURPLE='\033[01;35m'
CYAN='\033[01;36m'
WHITE='\033[01;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'

# ---------- Root check ----------
[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0"; exit 1; }

echo -e "${PURPLE}\n================================================\n${NONE}"
echo -e "${GREEN}Installing power-switch...${NONE}"
echo -e "${PURPLE}\n================================================\n${NONE}"

# ---------- Dependencies ----------
DEPS=(evtest cpupower)
MISSING=()
for dep in "${DEPS[@]}"; do
    command -v "$dep" >/dev/null 2>&1 || MISSING+=("$dep")
done

if [ "${#MISSING[@]}" -gt 0 ]; then
    echo -e "${PURPLE}\n================================================\n${NONE}"
    echo -e "${GREEN}Installing missing packages: ${MISSING[*]}${NONE}"
    echo -e "${PURPLE}\n================================================\n${NONE}"
    # cpupower ships inside linux-tools-common
    apt install -y evtest linux-tools-common linux-tools-generic > /dev/null 2>&1 || true
fi

# ---------- Install files ----------
install -d /usr/local/bin
install -d /usr/local/lib/power-switch
install -d /etc/systemd/system
install -d /etc/udev/rules.d

install -m755 bin/power-switch.sh           /usr/local/bin/power-switch.sh
install -m755 lib/kbd-backlight-daemon.sh   /usr/local/lib/power-switch/
install -m644 systemd/*.service             /etc/systemd/system/
install -m644 udev/*.rules                  /etc/udev/rules.d/

# ---------- Enable ----------
systemctl daemon-reload
systemctl enable --now kbd-backlight-daemon.service

udevadm control --reload-rules
udevadm trigger

# ---------- Run once for current power state ----------
/usr/local/bin/power-switch.sh

echo -e "${PURPLE}\n================================================\n${NONE}"
echo -e "${GREEN}Installed successfully${NONE}"
echo -e "${PURPLE}\n================================================\n${NONE}"
