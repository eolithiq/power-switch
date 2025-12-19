#!/bin/bash

set -e

echo "Uninstalling ..."

systemctl stop kbd-backlight-daemon.service 2>/dev/null || true
systemctl disable kbd-backlight-daemon.service 2>/dev/null || true

systemctl stop power-switch.service 2>/dev/null || true
systemctl disable power-switch.service 2>/dev/null || true

rm -f /usr/local/bin/power-switch.sh
rm -rf /usr/local/lib/power-switch
rm -f /etc/systemd/system/kbd-backlight-daemon.service
rm -f /etc/systemd/system/power-switch.service
rm -f /etc/udev/rules.d/98-power-switch.rules
rm -rf /var/lib/kbd-backlight
rm -f /var/log/kbd-backlight-daemon.log
rm -f /var/log/power-switch.log

sudo apt purge -y evtest > /dev/null 2>&1
sudo apt autoremove -y > /dev/null 2>&1

systemctl daemon-reload
udevadm control --reload-rules
udevadm trigger

echo "Uninstall completed successfully"