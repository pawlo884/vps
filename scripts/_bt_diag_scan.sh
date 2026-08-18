#!/bin/bash
set -u
echo "=== kernel bt ==="
dmesg -T 2>/dev/null | grep -iE 'bluetooth|hci0|firmware' | tail -40
echo
echo "=== service ==="
systemctl is-active bluetooth
journalctl -u bluetooth --no-pager -n 30 2>/dev/null || true
echo
echo "=== reset adapter ==="
sudo hciconfig hci0 down || true
sleep 1
sudo hciconfig hci0 up || true
sudo systemctl restart bluetooth
sleep 2
bluetoothctl power on
bluetoothctl pairable on
bluetoothctl discoverable on || true
echo
echo "=== hciconfig ==="
hciconfig -a
echo
echo "=== LE scan 20s (hcitool) ==="
sudo timeout 20 hcitool lescan --duplicates 2>&1 | tee /tmp/lescan.log | head -60 || true
echo "LE count: $(grep -c ':' /tmp/lescan.log 2>/dev/null || echo 0)"
echo
echo "=== classic inquiry 20s ==="
sudo timeout 20 hcitool scan --flush 2>&1 | tee /tmp/clscan.log
echo
echo "=== btmgmt find both 30s ==="
sudo timeout 30 btmgmt find 2>&1 | tee /tmp/btmgmt2.log
echo
echo "=== bluetoothctl devices ==="
bluetoothctl devices
echo
echo "=== grep sound/anker ==="
grep -iE 'sound|anker|core|Q30|Q35|Life|Space|Liberty|Motion|device|name' /tmp/lescan.log /tmp/clscan.log /tmp/btmgmt2.log 2>/dev/null || true
echo
echo "=== all unique MACs ==="
{ cat /tmp/lescan.log /tmp/clscan.log /tmp/btmgmt2.log 2>/dev/null; bluetoothctl devices; } | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | sort -u
