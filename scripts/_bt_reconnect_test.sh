#!/bin/bash
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/1000
MAC=18:9C:2C:20:D5:B8
DEV_PATH=/org/bluez/hci0/dev_18_9C_2C_20_D5_B8

echo "=== reconnect ==="
python3 <<'PY'
import time, dbus
from dbus.mainloop.glib import DBusGMainLoop
import gi
gi.require_version('GLib', '2.0')
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()
path = '/org/bluez/hci0/dev_18_9C_2C_20_D5_B8'
di = dbus.Interface(bus.get_object('org.bluez', path), 'org.bluez.Device1')
dp = dbus.Interface(bus.get_object('org.bluez', path), 'org.freedesktop.DBus.Properties')

def connected():
    return bool(dp.Get('org.bluez.Device1', 'Connected'))

print('before:', connected())
if connected():
    try:
        di.Disconnect()
        time.sleep(1)
    except Exception as e:
        print('disconnect:', e)

err = [None]
done = [False]
loop = GLib.MainLoop()

def ok(*a):
    done[0] = True
    loop.quit()

def bad(e):
    err[0] = str(e)
    loop.quit()

di.Connect(reply_handler=ok, error_handler=bad)
GLib.timeout_add_seconds(40, loop.quit)
loop.run()
time.sleep(2)
print('after:', connected(), 'err=', err[0])
if not connected():
    raise SystemExit(2)
PY

sleep 2
echo "=== sinks/cards ==="
pactl list short sinks
pactl list cards | grep -E 'bluez_card|connection|Active Profile' | head -20

SINK=$(pactl list short sinks | awk '/bluez_output/{print $2; exit}')
echo "sink=$SINK"
pactl set-card-profile bluez_card.18_9C_2C_20_D5_B8 a2dp-sink || true
sleep 1
SINK=$(pactl list short sinks | awk '/bluez_output/{print $2; exit}')
pactl set-default-sink "$SINK"
pactl set-sink-mute "$SINK" 0
pactl set-sink-volume "$SINK" 100%

# generate wav files locally then paplay (worked before)
WAVDIR=/tmp/bt-test-wav
mkdir -p "$WAVDIR"
ffmpeg -y -hide_banner -loglevel error -f lavfi -i sine=frequency=880:duration=1.5 -ac 2 "$WAVDIR/bip.wav"
ffmpeg -y -hide_banner -loglevel error -f lavfi -i sine=frequency=440:duration=1.5 -ac 2 -af 'pan=stereo|c0=c0|c1=0*c0' "$WAVDIR/left.wav"
ffmpeg -y -hide_banner -loglevel error -f lavfi -i sine=frequency=660:duration=1.5 -ac 2 -af 'pan=stereo|c0=0*c0|c1=c0' "$WAVDIR/right.wav"
ffmpeg -y -hide_banner -loglevel error -f lavfi -i sine=frequency=520:duration=1.5 -ac 2 "$WAVDIR/both.wav"

echo "1 bip"
paplay -v --device="$SINK" "$WAVDIR/bip.wav"
sleep 0.6
echo "2 LEWY"
paplay -v --device="$SINK" "$WAVDIR/left.wav"
sleep 0.6
echo "3 PRAWY"
paplay -v --device="$SINK" "$WAVDIR/right.wav"
sleep 0.6
echo "4 OBA"
paplay -v --device="$SINK" "$WAVDIR/both.wav"
echo DONE
pactl list cards | grep -E 'bluez_card|connection|Active Profile' | head -10
