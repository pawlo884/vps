#!/bin/bash
set -u
export XDG_RUNTIME_DIR=/run/user/1000
F=$(ls -t /home/pawel/Recordings/continuous/vad-*.wav 2>/dev/null | head -1)

echo "=== status ==="
echo -n "service: "; systemctl --user is-active bt-record-continuous.service
echo -n "ffmpeg: "; pgrep -c -f 'ffmpeg.*bluez_input' || true
python3 - <<'PY'
import dbus
bus=dbus.SystemBus()
d=dbus.Interface(bus.get_object('org.bluez','/org/bluez/hci0/dev_18_9C_2C_20_D5_B8'),'org.freedesktop.DBus.Properties')
print('BT Connected:', bool(d.Get('org.bluez.Device1','Connected')))
PY
pactl list short sources | grep bluez || echo 'brak bluez source'

echo "=== plik: $F ==="
ls -lh "$F"
ffprobe -v error -show_entries format=duration,size -of default=nw=1 "$F" 2>/dev/null || true

echo "=== test wzrostu przez 10s — mow do sluchawek ==="
s1=$(stat -c%s "$F")
sleep 10
s2=$(stat -c%s "$F")
echo "size before=$s1 after=$s2 delta=$((s2-s1))"
if [ "$s2" -gt "$s1" ]; then
  echo "WYNIK: NAGRYWA — plik rośnie"
else
  echo "WYNIK: nie urosło w 10s — przy VAD to normalne w ciszy; jak mowiles i zero, to problem"
fi
