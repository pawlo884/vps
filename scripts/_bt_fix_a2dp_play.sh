#!/bin/bash
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/1000
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"

echo "=== bluez connected? ==="
python3 <<'PY'
import dbus
bus=dbus.SystemBus()
om=dbus.Interface(bus.get_object('org.bluez','/'),'org.freedesktop.DBus.ObjectManager')
for path,ifaces in om.GetManagedObjects().items():
    d=ifaces.get('org.bluez.Device1')
    if not d: continue
    if '18:9C:2C:20:D5:B8' == str(d.get('Address')):
        print(path, 'Connected=', bool(d.get('Connected')), 'Paired=', bool(d.get('Paired')))
PY

echo "=== restart wireplumber/pipewire-pulse ==="
systemctl --user restart wireplumber.service pipewire.service pipewire-pulse.service || true
sleep 3

echo "=== reconnect device ==="
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
if bool(dp.Get('org.bluez.Device1','Connected')):
    try:
        di.Disconnect(); time.sleep(2)
    except Exception as e:
        print('disc', e)
loop=GLib.MainLoop(); err=[None]
di.Connect(reply_handler=lambda *a: loop.quit(), error_handler=lambda e: (err.__setitem__(0,str(e)), loop.quit()))
GLib.timeout_add_seconds(40, loop.quit)
loop.run()
time.sleep(3)
print('Connected', bool(dp.Get('org.bluez.Device1','Connected')), 'err', err[0])
PY

# wait until pipewire sees connected
for i in $(seq 1 15); do
  conn=$(pactl list cards 2>/dev/null | awk '/bluez_card.18_9C/{f=1} f&&/api.bluez5.connection/{print $3; exit}')
  echo "try $i pipewire connection=$conn"
  sinks=$(pactl list short sinks | grep bluez_output || true)
  echo "  sinks: $sinks"
  if [[ "$conn" == *"connected"* ]] || [[ -n "$sinks" && "$conn" != *"disconnected"* ]]; then
    break
  fi
  # force profile
  pactl set-card-profile bluez_card.18_9C_2C_20_D5_B8 a2dp-sink 2>/dev/null || true
  sleep 1
done

echo "=== final card ==="
pactl list cards | grep -A25 'bluez_card.18_9C' | head -30
SINK=$(pactl list short sinks | awk '/bluez_output/{print $2; exit}')
echo "SINK=$SINK"
if [[ -z "${SINK:-}" ]]; then
  echo "BRAK bluez sink"; exit 3
fi
pactl set-default-sink "$SINK"
pactl set-sink-mute "$SINK" 0
pactl set-sink-volume "$SINK" 100%

# also try moving to headset profile briefly if a2dp silent? stay a2dp
WAV=/tmp/bt-test-wav/bip.wav
ffmpeg -y -hide_banner -loglevel error -f lavfi -i sine=frequency=1000:duration=2 -ac 2 "$WAV"
echo "PLAY paplay 2s tone"
paplay -v --device="$SINK" "$WAV"
echo "PLAY speaker-test"
timeout 3 speaker-test -D pulse -c 2 -t sine -f 700 2>&1 | tail -15 || true
# pw-play if available
if command -v pw-play >/dev/null; then
  echo "PLAY pw-play"
  pw-play "$WAV" || true
fi
echo DONE
