#!/bin/bash
set -u
USB=00:1A:7D:DA:71:11
INTEL=98:3B:8F:E8:B2:EA

printf '%s\n' "select $USB" "power on" "scan on" | bluetoothctl >/dev/null 2>&1 &
sleep 25
echo "=== devices ==="
bluetoothctl devices
echo "=== match ==="
bluetoothctl devices | grep -iE '18:9C:2C|sound|anker|core' || echo "(brak Soundcore)"
printf '%s\n' "scan off" "select $INTEL" | bluetoothctl >/dev/null 2>&1

echo
echo "=== try connect known MAC ==="
bluetoothctl connect 18:9C:2C:20:D5:B8 2>&1 || true
sleep 2
bluetoothctl info 18:9C:2C:20:D5:B8 2>&1 | head -20 || true

echo
echo "=== service ==="
systemctl --user is-active bt-record-continuous.service
pgrep -af 'ffmpeg.*bluez' || echo "brak ffmpeg"
export XDG_RUNTIME_DIR=/run/user/1000
pactl list short sources | grep bluez || echo "brak bluez source"
