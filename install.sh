#!/bin/bash
set -e

# Create dirs
install -d /usr/local/bin
install -d /usr/local/lib/power-switch
install -d /etc/systemd/system
install -d /etc/udev/rules.d

# Install scripts
install -m755 bin/power-switch.sh /usr/local/bin/power-switch.sh
install -m755 lib/*.sh /usr/local/lib/power-switch/

# Install systemd units
install -m644 systemd/*.service /etc/systemd/system/
install -m644 systemd/*.timer /etc/systemd/system/

# Install udev rules
install -m644 udev/*.rules /etc/udev/rules.d/

# Reload
systemctl daemon-reload
systemctl enable --now kbd-backlight-off.timer
udevadm control --reload-rules
udevadm trigger

echo "Installed successfully"