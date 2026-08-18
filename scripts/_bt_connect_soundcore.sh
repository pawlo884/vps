#!/bin/bash
set -u
LOG=/tmp/bt-soundcore.log
: > "$LOG"

echo "=== kontrolery ==="
bluetoothctl list | tee -a "$LOG"

# Prefer USB dongle for scan+connect
USB=00:1A:7D:DA:71:11
INTEL=98:3B:8F:E8:B2:EA

use_ctrl() {
  local mac="$1"
  printf '%s\n' "select $mac" "power on" "pairable on" "agent on" "default-agent" "quit" | bluetoothctl >/dev/null 2>&1
}

scan_on() {
  local mac="$1"
  printf '%s\n' "select $mac" "scan on" | bluetoothctl >>"$LOG" 2>&1 &
  echo $!
}

echo "=== skan 35s na USB dongle ==="
use_ctrl "$USB"
# interactive scan
coproc BT { stdbuf -oL bluetoothctl; }
sleep 1
echo "select $USB" >&"${BT[1]}"
sleep 0.3
echo "scan on" >&"${BT[1]}"
sleep 35
echo "devices" >&"${BT[1]}"
sleep 1
echo "scan off" >&"${BT[1]}"
sleep 0.5
echo "quit" >&"${BT[1]}"
wait "$BT_PID" 2>/dev/null || true

echo "=== wszystkie urządzenia ==="
bluetoothctl devices | tee -a "$LOG"
echo
echo "=== filtr Soundcore/Anker ==="
MATCHES=$(bluetoothctl devices | grep -iE 'sound|anker|core|Q[0-9]|Life|Space|Liberty|Motion|Neo|Aero|Sport|Bud' || true)
if [[ -z "$MATCHES" ]]; then
  echo "(brak po nazwie — pokazuję wszystko z info)"
  bluetoothctl devices
  # also try Intel scan quickly
  echo "=== dodatkowy skan Intel 20s ==="
  coproc BT2 { stdbuf -oL bluetoothctl; }
  sleep 1
  echo "select $INTEL" >&"${BT2[1]}"
  sleep 0.3
  echo "scan on" >&"${BT2[1]}"
  sleep 20
  echo "devices" >&"${BT2[1]}"
  sleep 1
  echo "scan off" >&"${BT2[1]}"
  sleep 0.5
  echo "quit" >&"${BT2[1]}"
  wait "$BT2_PID" 2>/dev/null || true
  bluetoothctl devices
  MATCHES=$(bluetoothctl devices | grep -iE 'sound|anker|core|Q[0-9]|Life|Space|Liberty|Motion|Neo|Aero|Sport|Bud' || true)
fi

echo "$MATCHES"
TARGET_MAC=""
TARGET_NAME=""
if [[ -n "$MATCHES" ]]; then
  TARGET_MAC=$(echo "$MATCHES" | head -1 | awk '{print $2}')
  TARGET_NAME=$(echo "$MATCHES" | head -1 | cut -d' ' -f3-)
fi

# If still no name match, pick audio-looking devices from recent scan via dbus
if [[ -z "$TARGET_MAC" ]]; then
  echo "=== dbus devices with Class/Icon audio ==="
  python3 <<'PY' | tee /tmp/bt-audio-devs.txt
import dbus
bus = dbus.SystemBus()
om = dbus.Interface(bus.get_object('org.bluez', '/'), 'org.freedesktop.DBus.ObjectManager')
for path, ifaces in om.GetManagedObjects().items():
    d = ifaces.get('org.bluez.Device1')
    if not d: continue
    name = str(d.get('Name') or d.get('Alias') or '')
    addr = str(d.get('Address'))
    icon = str(d.get('Icon') or '')
    cls = int(d.get('Class') or 0)
    rssi = d.get('RSSI', None)
    # Audio Major class 0x04xxxx or headphones bit
    is_audio = ('audio' in icon) or ((cls >> 8) & 0x1f) in (2,4,5,6,7,8) or True
    print(f"{addr}\tRSSI={rssi}\tclass=0x{cls:06x}\ticon={icon}\t{name}")
PY
  # Prefer name match in python output
  TARGET_MAC=$(grep -iE 'sound|anker|core' /tmp/bt-audio-devs.txt | head -1 | awk '{print $1}' || true)
  if [[ -z "$TARGET_MAC" ]]; then
    # strongest RSSI non-empty name
    TARGET_MAC=$(awk -F'\t' '$2 ~ /RSSI=-[0-9]/ && $5!=""{print}' /tmp/bt-audio-devs.txt | head -1 | awk '{print $1}' || true)
  fi
fi

if [[ -z "$TARGET_MAC" ]]; then
  echo "FAIL: nie znaleziono Soundcore w zasięgu"
  exit 2
fi

echo "=== łączę z: $TARGET_MAC ($TARGET_NAME) przez USB ==="
printf '%s\n' \
  "select $USB" \
  "scan off" \
  "pair $TARGET_MAC" \
  "trust $TARGET_MAC" \
  "connect $TARGET_MAC" \
  "info $TARGET_MAC" \
  "quit" | bluetoothctl 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tee -a "$LOG"

echo
echo "=== status końcowy ==="
bluetoothctl info "$TARGET_MAC" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'Name|Alias|Paired|Trusted|Connected|Icon|UUID' | head -30
bluetoothctl devices Connected
~/bin/bt-status 2>/dev/null | tail -30 || true
