#!/bin/bash
set -u

echo "=== USB BT device ==="
lsusb | grep -i intel
BTUSB=$(lsusb -d 8087: | head -1)
echo "$BTUSB"
# find sysfs for autosuspend
for d in /sys/bus/usb/devices/*; do
  if [[ -f "$d/idVendor" ]] && grep -qx 8087 "$d/idVendor" 2>/dev/null; then
    echo "sysfs: $d"
    echo -n "autosuspend="; cat "$d/power/autosuspend" 2>/dev/null || true
    echo -n "control="; cat "$d/power/control" 2>/dev/null || true
    echo on > "$d/power/control" 2>/dev/null || true
  fi
done

echo
echo "=== firmware ==="
ls -la /lib/firmware/intel/ibt-* 2>/dev/null | tail -20
modinfo btusb 2>/dev/null | head -5
dmesg | grep -iE 'Bluetooth.*firmware|ibt-|hci0.*failed|hci0.*error' | tail -20

echo
echo "=== RAW scan: stop bluetoothd, hcitool ==="
systemctl stop bluetooth
sleep 1
hciconfig hci0 up
hciconfig hci0 piscan
echo "Classic inquiry 25s..."
timeout 25 hcitool scan --flush 2>&1 | tee /tmp/raw-classic.log
echo "LE scan 25s..."
timeout 25 hcitool lescan --duplicates 2>&1 | tee /tmp/raw-le.log || true
echo "btmon sniff briefly while scanning..."
timeout 8 btmon 2>&1 | tee /tmp/btmon.log | head -40 || true

echo
echo "=== restart bluetoothd ==="
systemctl start bluetooth
sleep 2
bluetoothctl power on
bluetoothctl pairable on

echo
echo "=== bluetoothctl Dual scan 35s (python dbus) ==="
python3 <<'PY'
import time, sys
try:
    import dbus
    from dbus.mainloop.glib import DBusGMainLoop
    import gi
    gi.require_version('GLib', '2.0')
    from gi.repository import GLib
except Exception as e:
    print("dbus/gi missing:", e)
    sys.exit(0)

DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()
adapter = dbus.Interface(bus.get_object('org.bluez', '/org/bluez/hci0'), 'org.bluez.Adapter1')
props = dbus.Interface(bus.get_object('org.bluez', '/org/bluez/hci0'), 'org.freedesktop.DBus.Properties')
props.Set('org.bluez.Adapter1', 'Powered', dbus.Boolean(True))
props.Set('org.bluez.Adapter1', 'Pairable', dbus.Boolean(True))

found = {}

def interfaces_added(path, interfaces):
    if 'org.bluez.Device1' in interfaces:
        d = interfaces['org.bluez.Device1']
        addr = str(d.get('Address', path))
        name = str(d.get('Name') or d.get('Alias') or '')
        found[addr] = name
        print(f"FOUND {addr}  {name}", flush=True)

bus.add_signal_receiver(interfaces_added, dbus_interface='org.freedesktop.DBus.ObjectManager', signal_name='InterfacesAdded')

# clear filter
try:
    adapter.SetDiscoveryFilter(dbus.Dictionary({
        'Transport': dbus.String('auto'),
        'DuplicateData': dbus.Boolean(True),
    }, signature='sv'))
except Exception as e:
    print("filter:", e)

print("StartDiscovery...", flush=True)
adapter.StartDiscovery()
loop = GLib.MainLoop()
GLib.timeout_add_seconds(35, loop.quit)
loop.run()
try:
    adapter.StopDiscovery()
except Exception:
    pass

print("--- summary ---")
if not found:
    # list managed objects
    om = dbus.Interface(bus.get_object('org.bluez', '/'), 'org.freedesktop.DBus.ObjectManager')
    objects = om.GetManagedObjects()
    for path, ifaces in objects.items():
        if 'org.bluez.Device1' in ifaces:
            d = ifaces['org.bluez.Device1']
            print(d.get('Address'), d.get('Name') or d.get('Alias'))
else:
    for a,n in found.items():
        print(a, n)
print(f"count={len(found)}")
PY

echo
echo "=== results ==="
echo "classic:"; cat /tmp/raw-classic.log
echo "le:"; head -40 /tmp/raw-le.log
echo "devices:"; bluetoothctl devices
