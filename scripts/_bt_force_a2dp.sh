#!/bin/bash
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/1000
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus

INTEL=98:3B:8F:E8:B2:EA
USB=00:1A:7D:DA:71:11
MAC=18:9C:2C:20:D5:B8

echo "=== power off INTEL adapter ==="
python3 <<PY
import dbus
bus=dbus.SystemBus()
om=dbus.Interface(bus.get_object('org.bluez','/'),'org.freedesktop.DBus.ObjectManager')
for path,ifaces in om.GetManagedObjects().items():
    a=ifaces.get('org.bluez.Adapter1')
    if not a: continue
    addr=str(a.get('Address'))
    p=dbus.Interface(bus.get_object('org.bluez', path),'org.freedesktop.DBus.Properties')
    if addr=='$INTEL':
        print('power off', addr, path)
        p.Set('org.bluez.Adapter1','Powered', dbus.Boolean(False))
    elif addr=='$USB':
        print('power on', addr, path)
        p.Set('org.bluez.Adapter1','Powered', dbus.Boolean(True))
        p.Set('org.bluez.Adapter1','Pairable', dbus.Boolean(True))
PY

sleep 1
systemctl --user restart wireplumber pipewire pipewire-pulse
sleep 3

echo "=== MediaEndpoint / Transport before connect ==="
busctl tree org.bluez 2>/dev/null | head -80 || true

echo "=== disconnect+connect via USB ==="
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
print('adapter', dp.Get('org.bluez.Device1','Adapter'))
if bool(dp.Get('org.bluez.Device1','Connected')):
    di.Disconnect(); time.sleep(2)

loop=GLib.MainLoop(); err=[None]
di.Connect(reply_handler=lambda *a: loop.quit(), error_handler=lambda e:(err.__setitem__(0,str(e)), loop.quit()))
GLib.timeout_add_seconds(45, loop.quit)
loop.run()
time.sleep(4)
print('Connected', bool(dp.Get('org.bluez.Device1','Connected')), err[0])

# list media transports
om=dbus.Interface(bus.get_object('org.bluez','/'),'org.freedesktop.DBus.ObjectManager')
print('--- transports ---')
for p,ifaces in om.GetManagedObjects().items():
    if 'org.bluez.MediaTransport1' in ifaces:
        t=ifaces['org.bluez.MediaTransport1']
        print(p, dict((k,str(v)) for k,v in t.items() if k in ('UUID','State','Device','Codec')))
    if 'org.bluez.MediaPlayer1' in ifaces:
        print('player', p)
PY

echo "=== pipewire card ==="
for i in 1 2 3 4 5 6 7 8; do
  pactl set-card-profile bluez_card.18_9C_2C_20_D5_B8 a2dp-sink 2>/dev/null || true
  conn=$(pactl list cards | awk '/Name: bluez_card.18_9C/{f=1} f&&/api.bluez5.connection/{gsub(/"/,""); print $3; exit}')
  prof=$(pactl list cards | awk '/Name: bluez_card.18_9C/{f=1} f&&/Active Profile:/{print $3; exit}')
  echo "i=$i connection=$conn profile=$prof"
  [[ "$conn" == "connected" ]] && break
  sleep 1
done

pactl list cards | grep -A35 'Name: bluez_card.18_9C' | head -40
SINK=$(pactl list short sinks | awk '/bluez_output/{print $2; exit}')
echo SINK=$SINK
pactl list sinks | grep -A15 "Name: $SINK" | head -20

# journal hints
journalctl --user -u wireplumber -n 30 --no-pager 2>/dev/null | tail -30 || true

if [[ -n "${SINK:-}" ]]; then
  pactl set-default-sink "$SINK"
  pactl set-sink-volume "$SINK" 100%
  pactl set-sink-mute "$SINK" 0
  ffmpeg -y -hide_banner -loglevel error -f lavfi -i sine=frequency=880:duration=2.5 -ac 2 /tmp/bip2.wav
  echo "=== PLAY ==="
  paplay -v --device="$SINK" /tmp/bip2.wav
  # also play Front_Center which user heard before
  paplay -v --device="$SINK" /usr/share/sounds/alsa/Front_Center.wav || true
fi
echo DONE
