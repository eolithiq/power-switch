# Power Switch

Universal AC/BATTERY power management for Linux laptops.

## Features

- AMD Ryzen & Intel CPU auto-detection
- CPU boost / turbo control
- NVIDIA runtime power management
- Keyboard backlight:
  - Battery: always OFF
  - AC: ON only while typing
  - Auto-OFF after 120s inactivity
  - Restores last user-set brightness level
- Correct CPU max frequency from `/sys/cpufreq` (not `/proc/cpuinfo`)
- No GUI, no cron, no deb
- systemd + udev only
- Fully configurable via scripts

## Requirements

Ubuntu 24.04+. The installer handles dependencies automatically (`evtest`, `cpupower`).

## Installation

```bash
sudo ./install.sh
```

## Uninstall

```bash
sudo ./uninstall.sh
```

## Logs

```bash
tail -f /var/log/power-switch.log
tail -f /var/log/kbd-backlight-daemon.log
```

## Donate

If you find this project useful, you can support development:

- [Monobank](https://send.monobank.ua/jar/3guo8A1qre)
- Cryptocurrency:
  - USDT (ARB): `0x9dfa277f6071f50a23ec5770f572a8fe45c793e6`

Thank you for your support! ❤️
