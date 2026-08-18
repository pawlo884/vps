#!/bin/bash
# Robust BT scan for Soundcore / nearby devices
set -u
bluetoothctl power on >/dev/null 2>&1
bluetoothctl pairable on >/dev/null 2>&1 || true

echo "=== Adapter ==="
bluetoothctl show | sed -n '1,10p'

echo
echo "=== btmgmt find (25s) ==="
sudo timeout 25 btmgmt find -l 2>&1 | tee /tmp/btmgmt.log || true

echo
echo "=== bluetoothctl scan via stdbuf ==="
# Use unbuffered bluetoothctl with timeout
(
  stdbuf -oL bluetoothctl 2>&1 &
  pid=$!
  sleep 0.5
  # send via /proc if possible - fallback: expect-style with coproc
  kill "$pid" 2>/dev/null || true
) >/dev/null 2>&1 || true

coproc BT { stdbuf -oL bluetoothctl; }
sleep 1
echo "scan on" >&"${BT[1]}"
sleep 28
echo "devices" >&"${BT[1]}"
sleep 1
echo "scan off" >&"${BT[1]}"
sleep 1
echo "quit" >&"${BT[1]}"
wait "$BT_PID" 2>/dev/null || true

echo
echo "=== devices ==="
bluetoothctl devices
echo
echo "=== filter Soundcore/Anker/audio ==="
bluetoothctl devices | grep -iE 'sound|anker|core|head|bud|audio|ear' || echo "(brak dopasowania nazwy)"
echo
echo "=== raw NEW from btmgmt ==="
grep -iE 'dev_found|name|rssi|addr' /tmp/btmgmt.log | head -80 || true
echo
echo "=== all devices with info ==="
while read -r _ mac rest; do
  [[ -z "${mac:-}" ]] && continue
  echo "--- $mac $rest ---"
  bluetoothctl info "$mac" 2>/dev/null | sed -n '1,15p'
done < <(bluetoothctl devices)
