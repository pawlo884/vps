#!/bin/bash
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/1000
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus

echo "=== enable INTEL, keep USB ==="
python3 <<'PY'
import dbus, time
from dbus.mainloop.glib import DBusGMainLoop
import gi
gi.require_version('GLib','2.0')
from gi.repository import GLib
DBusGMainLoop(set_as_default=True)
bus=dbus.SystemBus()
om=dbus.Interface(bus.get_object('org.bluez','/'),'org.freedesktop.DBus.ObjectManager')

def set_power(addr, on):
    for path,ifaces in om.GetManagedObjects().items():
        a=ifaces.get('org.bluez.Adapter1')
        if a and str(a.get('Address'))==addr:
            p=dbus.Interface(bus.get_object('org.bluez', path),'org.freedesktop.DBus.Properties')
            p.Set('org.bluez.Adapter1','Powered', dbus.Boolean(on))
            print(('on' if on else 'off'), addr, path)
            return path
    return None

set_power('00:1A:7D:DA:71:11', True)
set_power('98:3B:8F:E8:B2:EA', True)

# disconnect current
path='/org/bluez/hci0/dev_18_9C_2C_20_D5_B8'
try:
    di=dbus.Interface(bus.get_object('org.bluez', path),'org.bluez.Device1')
    dp=dbus.Interface(bus.get_object('org.bluez', path),'org.freedesktop.DBus.Properties')
    if bool(dp.Get('org.bluez.Device1','Connected')):
        di.Disconnect(); time.sleep(2)
        print('disconnected from hci0')
except Exception as e:
    print('hci0 disc', e)

# remove device from USB and pair on INTEL if needed
INTEL_PATH=None
for path,ifaces in om.GetManagedObjects().items():
    a=ifaces.get('org.bluez.Adapter1')
    if a and str(a.get('Address'))=='98:3B:8F:E8:B2:EA':
        INTEL_PATH=path
print('intel adapter', INTEL_PATH)

ai=dbus.Interface(bus.get_object('org.bluez', INTEL_PATH),'org.bluez.Adapter1')
# scan briefly
found={}
def on_added(p, interfaces):
    if 'org.bluez.Device1' in interfaces:
        d=interfaces['org.bluez.Device1']
        found[str(d.get('Address'))]=(p, str(d.get('Name') or ''))
        print('FOUND', d.get('Address'), d.get('Name'))
bus.add_signal_receiver(on_added, dbus_interface='org.freedesktop.DBus.ObjectManager', signal_name='InterfacesAdded')
try:
    ai.SetDiscoveryFilter(dbus.Dictionary({'Transport': dbus.String('auto')}, signature='sv'))
except Exception:
    pass
ai.StartDiscovery()
loop=GLib.MainLoop(); GLib.timeout_add_seconds(20, loop.quit); loop.run()
try: ai.StopDiscovery()
except Exception: pass

# find soundcore under intel or any
target=None
for p,ifaces in om.GetManagedObjects().items():
    d=ifaces.get('org.bluez.Device1')
    if not d: continue
    if str(d.get('Address'))=='18:9C:2C:20:D5:B8' or 'soundcore' in str(d.get('Name') or '').lower():
        print('candidate', p, d.get('Name'), d.get('Adapter'))
        if str(d.get('Adapter'))==INTEL_PATH:
            target=p
if not target:
    # try connect existing on hci0 again and monitor transport during play
    target='/org/bluez/hci0/dev_18_9C_2C_20_D5_B8'
    print('fallback target', target)
else:
    print('using intel target', target)

di=dbus.Interface(bus.get_object('org.bluez', target),'org.bluez.Device1')
dp=dbus.Interface(bus.get_object('org.bluez', target),'org.freedesktop.DBus.Properties')
try: dp.Set('org.bluez.Device1','Trusted', dbus.Boolean(True))
except Exception: pass
if not bool(dp.Get('org.bluez.Device1','Paired')):
    loop=GLib.MainLoop(); err=[None]
    di.Pair(reply_handler=lambda *a: loop.quit(), error_handler=lambda e:(err.__setitem__(0,str(e)), loop.quit()))
    GLib.timeout_add_seconds(60, loop.quit); loop.run(); print('pair err', err[0])

loop=GLib.MainLoop(); err=[None]
di.Connect(reply_handler=lambda *a: loop.quit(), error_handler=lambda e:(err.__setitem__(0,str(e)), loop.quit()))
GLib.timeout_add_seconds(45, loop.quit); loop.run()
time.sleep(3)
print('Connected', bool(dp.Get('org.bluez.Device1','Connected')), 'Adapter', dp.Get('org.bluez.Device1','Adapter'), 'err', err[0])

om=dbus.Interface(bus.get_object('org.bluez','/'),'org.freedesktop.DBus.ObjectManager')
print('transports:')
for p,ifaces in om.GetManagedObjects().items():
    if 'org.bluez.MediaTransport1' in ifaces:
        t=ifaces['org.bluez.MediaTransport1']
        print(p, 'State=', t.get('State'), 'UUID=', t.get('UUID'))
PY

sleep 2
pactl set-card-profile bluez_card.18_9C_2C_20_D5_B8 a2dp-sink || true
sleep 1
echo "=== pipewire ==="
pactl list cards | grep -E 'bluez_card|connection|Active Profile|bluez5.profile' | head -20
SINK=$(pactl list short sinks | awk '/bluez_output/{print $2; exit}')
echo SINK=$SINK

# monitor transport state in background during play
python3 <<'PY' &
import time, dbus
bus=dbus.SystemBus()
om=dbus.Interface(bus.get_object('org.bluez','/'),'org.freedesktop.DBus.ObjectManager')
for i in range(30):
    for p,ifaces in om.GetManagedObjects().items():
        if 'org.bluez.MediaTransport1' in ifaces:
            t=ifaces['org.bluez.MediaTransport1']
            print(f't[{i}]', p.split('/')[-1], 'State=', t.get('State'), flush=True)
    time.sleep(0.3)
PY
MON=$!
sleep 0.5
pactl set-default-sink "$SINK" || true
pactl set-sink-volume "$SINK" 100% || true
ffmpeg -y -hide_banner -loglevel error -f lavfi -i sine=frequency=1000:duration=3 -ac 2 /tmp/bip3.wav
echo PLAY
paplay --device="$SINK" /tmp/bip3.wav || paplay /tmp/bip3.wav
paplay --device="$SINK" /usr/share/sounds/alsa/Front_Center.wav || true
wait $MON || true
echo DONE
