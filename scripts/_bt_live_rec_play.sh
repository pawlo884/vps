#!/bin/bash
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/1000
CARD=bluez_card.18_9C_2C_20_D5_B8
OUT=/home/pawel/Recordings/live-$(date +%Y%m%d-%H%M%S).wav
mkdir -p /home/pawel/Recordings

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
    GLib.timeout_add_seconds(30, loop.quit); loop.run(); time.sleep(2)
print('Connected', bool(dp.Get('org.bluez.Device1','Connected')))
PY

echo "=== HFP mic ==="
pactl set-card-profile "$CARD" headset-head-unit-msbc
sleep 2
SRC=$(pactl list short sources | awk '/bluez_input/{print $2; exit}')
echo "SRC=$SRC"
pactl set-source-mute "$SRC" 0
pactl set-source-volume "$SRC" 100%

echo "=== NAGRYWANIE 8s — MÓW TERAZ ==="
ffmpeg -y -hide_banner -loglevel error -f pulse -i "$SRC" -t 8 -ac 1 -ar 16000 "$OUT"
ls -lh "$OUT"
echo "OUT=$OUT"

echo "=== A2DP playback ==="
pactl set-card-profile "$CARD" a2dp-sink
sleep 2
SINK=$(pactl list short sinks | awk '/bluez_output/{print $2; exit}')
echo "SINK=$SINK"
pactl set-default-sink "$SINK"
pactl set-sink-mute "$SINK" 0
pactl set-sink-volume "$SINK" 100%
ffmpeg -y -hide_banner -loglevel error -i "$OUT" -ar 44100 -ac 2 /tmp/live-play.wav
echo "=== ODTWARZAM ==="
paplay --device="$SINK" /tmp/live-play.wav
echo DONE
