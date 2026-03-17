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

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo $0"; exit 1; }

echo -e "${PURPLE}\n================================================\n${NONE}"
echo -e "${GREEN}Uninstalling power-switch...${NONE}"
echo -e "${PURPLE}\n================================================\n${NONE}"

for svc in kbd-backlight-daemon.service power-switch.service; do
    systemctl stop    "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
done

rm -f  /usr/local/bin/power-switch.sh
rm -rf /usr/local/lib/power-switch
rm -f  /etc/systemd/system/kbd-backlight-daemon.service
rm -f  /etc/systemd/system/power-switch.service
rm -f  /etc/udev/rules.d/98-power-switch.rules
rm -rf /var/lib/kbd-backlight
rm -f  /var/log/kbd-backlight-daemon.log
rm -f  /var/log/power-switch.log

systemctl daemon-reload
udevadm control --reload-rules
udevadm trigger

echo -e "${PURPLE}\n================================================\n${NONE}"
echo -e "${GREEN}Uninstalled successfully${NONE}"
echo -e "${PURPLE}\n================================================\n${NONE}"
