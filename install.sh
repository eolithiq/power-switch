#!/bin/bash

set -e

echo "Installing ..."

sudo apt install -y evtest > /dev/null 2>&1

install -d /usr/local/bin
install -d /usr/local/lib/power-switch
install -d /etc/systemd/system
install -d /etc/udev/rules.d

install -m755 bin/power-switch.sh /usr/local/bin/power-switch.sh
install -m755 lib/kbd-backlight-daemon.sh /usr/local/lib/power-switch/
install -m644 systemd/*.service /etc/systemd/system/
install -m644 udev/*.rules /etc/udev/rules.d/

systemctl daemon-reload
systemctl enable --now kbd-backlight-daemon.service
udevadm control --reload-rules
udevadm trigger

echo "Installed successfully"