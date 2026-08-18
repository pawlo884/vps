#!/bin/bash
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/1000
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus

OUT_DIR=/home/pawel/Recordings/continuous/test-vad
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# stop scheduled continuous if running
systemctl --user stop bt-record-continuous.service 2>/dev/null || true

# short test: same logic, 40s max, write to test dir
export HOME=/home/pawel
CARD=bluez_card.18_9C_2C_20_D5_B8
MAC_PATH=/org/bluez/hci0/dev_18_9C_2C_20_D5_B8
VAD_DB=-38dB
VAD_STOP_SEC=1.5
VAD_START_SEC=0.15

python3 <<'PY'
import time, dbus
from dbus.mainloop.glib import DBusGMainLoop
import gi
gi.require_version('GLib','2.0')
from gi.repository import GLib
DBusGMainLoop(set_as_default=True)
bus=dbus.SystemBus()
path='/org/bluez/hci0/dev_18_9C_2C_20_D5_B8'
di=dbus.Interface(bus.get_object('org.bluez', path),'org.bluez.Device1')
dp=dbus.Interface(bus.get_object('org.bluez', path),'org.freedesktop.DBus.Properties')
if not bool(dp.Get('org.bluez.Device1','Connected')):
    loop=GLib.MainLoop()
    di.Connect(reply_handler=lambda *a: loop.quit(), error_handler=lambda e: loop.quit())
    GLib.timeout_add_seconds(40, loop.quit); loop.run(); time.sleep(2)
print('Connected', bool(dp.Get('org.bluez.Device1','Connected')))
PY

for prof in headset-head-unit-msbc headset-head-unit-cvsd headset-head-unit; do
  pactl set-card-profile "$CARD" "$prof" 2>/dev/null || true
  sleep 1
  pactl list short sources | grep -q bluez_input && break
done
while read -r s; do pactl set-sink-mute "$s" 1; pactl set-sink-volume "$s" 0; done < <(pactl list short sinks | awk '{print $2}')
SRC=$(pactl list short sources | awk '/bluez_input/{print $2; exit}')
echo "SRC=$SRC"
pactl set-source-mute "$SRC" 0
pactl set-source-volume "$SRC" 100%

AF="silenceremove=start_periods=1:start_duration=${VAD_START_SEC}:start_threshold=${VAD_DB}:stop_periods=-1:stop_duration=${VAD_STOP_SEC}:stop_threshold=${VAD_DB}:detection=peak"
OUT="$OUT_DIR/vad-test.wav"

echo "=== NAGRYWANIE VAD 40s — IDŹ I MÓW ==="
timeout 40 ffmpeg -y -hide_banner -loglevel info \
  -f pulse -i "$SRC" -ac 1 -ar 16000 -af "$AF" "$OUT" 2>"$OUT_DIR/ffmpeg.log" || true

echo "=== wynik ==="
ls -lh "$OUT_DIR" || true
if [[ -f "$OUT" ]]; then
  ffprobe -hide_banner -show_entries format=duration,size -of default=nw=1 "$OUT" 2>/dev/null || true
  # play back on A2DP
  pactl set-card-profile "$CARD" a2dp-sink || true
  sleep 2
  SINK=$(pactl list short sinks | awk '/bluez_output/{print $2; exit}')
  pactl set-sink-mute "$SINK" 0
  pactl set-sink-volume "$SINK" 100%
  ffmpeg -y -hide_banner -loglevel error -i "$OUT" -ar 44100 -ac 2 /tmp/vad-play.wav
  echo "=== ODTWARZAM to co złapał VAD ==="
  paplay --device="$SINK" /tmp/vad-play.wav || paplay /tmp/vad-play.wav
else
  echo "BRAK PLIKU — VAD nic nie zapisał (za wysoki próg albo cisza)"
  tail -30 "$OUT_DIR/ffmpeg.log" || true
fi
echo DONE
