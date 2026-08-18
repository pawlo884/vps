#!/bin/bash
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/1000
SINK=$(pactl list short sinks | awk '/bluez_output/{print $2; exit}')
echo "SINK=$SINK Connected check..."
python3 - <<'PY'
import dbus
bus=dbus.SystemBus()
dp=dbus.Interface(bus.get_object('org.bluez','/org/bluez/hci0/dev_18_9C_2C_20_D5_B8'),'org.freedesktop.DBus.Properties')
print('BT Connected', bool(dp.Get('org.bluez.Device1','Connected')))
om=dbus.Interface(bus.get_object('org.bluez','/'),'org.freedesktop.DBus.ObjectManager')
for p,ifaces in om.GetManagedObjects().items():
    if 'org.bluez.MediaTransport1' in ifaces:
        t=ifaces['org.bluez.MediaTransport1']
        print('Transport State', t.get('State'), 'Volume', t.get('Volume'))
        try:
            dbus.Interface(bus.get_object('org.bluez', p),'org.freedesktop.DBus.Properties').Set('org.bluez.MediaTransport1','Volume', dbus.UInt16(127))
        except Exception as e:
            print(e)
PY
pactl set-default-sink "$SINK"
pactl set-sink-mute "$SINK" 0
pactl set-sink-volume "$SINK" 100%
ffmpeg -y -hide_banner -loglevel error -f lavfi -i sine=frequency=880:duration=3 -ac 2 /tmp/loud.wav
echo "PLAY tone 3s + Front_Center — sluchaj teraz"
paplay --device="$SINK" /tmp/loud.wav
paplay --device="$SINK" /usr/share/sounds/alsa/Front_Center.wav
echo DONE
