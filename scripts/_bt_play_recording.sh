#!/bin/bash
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/1000
WAV=/home/pawel/Recordings/bt-mic-20260716-150519.wav
ls -lh "$WAV"

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

pactl set-card-profile bluez_card.18_9C_2C_20_D5_B8 a2dp-sink || true
sleep 2
SINK=$(pactl list short sinks | awk '/bluez_output/{print $2; exit}')
echo "SINK=$SINK"
pactl set-default-sink "$SINK"
pactl set-sink-mute "$SINK" 0
pactl set-sink-volume "$SINK" 100%
ffmpeg -y -hide_banner -loglevel error -i "$WAV" -ar 44100 -ac 2 /tmp/rec-play.wav
echo "Odtwarzam nagranie na Q11i..."
paplay --device="$SINK" /tmp/rec-play.wav
echo DONE
