#!/bin/bash
set -e

echo "Uninstalling ..."

# Stop & disable timers/services
systemctl stop kbd-backlight-off.timer 2>/dev/null || true
systemctl disable kbd-backlight-off.timer 2>/dev/null || true

systemctl stop power-switch.service 2>/dev/null || true
systemctl disable power-switch.service 2>/dev/null || true

systemctl stop kbd-backlight-on.service 2>/dev/null || true
systemctl stop kbd-backlight-off.service 2>/dev/null || true
systemctl stop kbd-backlight-battery.service 2>/dev/null || true

# Remove systemd units
rm -f \
    /etc/systemd/system/power-switch.service \
    /etc/systemd/system/kbd-backlight-on.service \
    /etc/systemd/system/kbd-backlight-off.service \
    /etc/systemd/system/kbd-backlight-off.timer \
    /etc/systemd/system/kbd-backlight-battery.service

# Remove udev rules
rm -f \
    /etc/udev/rules.d/98-power-switch.rules \
    /etc/udev/rules.d/98-power-backlight.rules \
    /etc/udev/rules.d/99-kbd-backlight.rules

# Remove scripts
rm -f /usr/local/bin/power-switch.sh
rm -rf /usr/local/lib/power-switch

# Remove runtime state
rm -f /run/kbd-backlight.level
rm -f /var/log/power-switch.log

# Reload system
systemctl daemon-reload
udevadm control --reload-rules
udevadm trigger

echo "Uninstall completed successfully"