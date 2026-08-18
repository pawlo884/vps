#!/usr/bin/env python3
"""Scan + pair + connect Soundcore via BlueZ D-Bus (USB adapter preferred)."""
import sys
import time
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
import gi
gi.require_version('GLib', '2.0')
from gi.repository import GLib

USB = '00:1A:7D:DA:71:11'
INTEL = '98:3B:8F:E8:B2:EA'
TARGET_NAME_SUB = 'soundcore'
KNOWN_MAC = '18:9C:2C:20:D5:B8'

DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()
om = dbus.Interface(bus.get_object('org.bluez', '/'), 'org.freedesktop.DBus.ObjectManager')

# Minimal auto-accept pairing agent
class Agent(dbus.service.Object):
    @dbus.service.method('org.bluez.Agent1', in_signature='', out_signature='')
    def Release(self):
        pass

    @dbus.service.method('org.bluez.Agent1', in_signature='o', out_signature='s')
    def RequestPinCode(self, device):
        return '0000'

    @dbus.service.method('org.bluez.Agent1', in_signature='o', out_signature='u')
    def RequestPasskey(self, device):
        return dbus.UInt32(0)

    @dbus.service.method('org.bluez.Agent1', in_signature='ouq', out_signature='')
    def DisplayPasskey(self, device, passkey, entered):
        print(f'Passkey {passkey}', flush=True)

    @dbus.service.method('org.bluez.Agent1', in_signature='os', out_signature='')
    def DisplayPinCode(self, device, pincode):
        print(f'PIN {pincode}', flush=True)

    @dbus.service.method('org.bluez.Agent1', in_signature='ou', out_signature='')
    def RequestConfirmation(self, device, passkey):
        print(f'Confirm passkey {passkey}', flush=True)

    @dbus.service.method('org.bluez.Agent1', in_signature='o', out_signature='')
    def RequestAuthorization(self, device):
        pass

    @dbus.service.method('org.bluez.Agent1', in_signature='os', out_signature='')
    def AuthorizeService(self, device, uuid):
        pass

    @dbus.service.method('org.bluez.Agent1', in_signature='', out_signature='')
    def Cancel(self):
        pass

AGENT_PATH = '/test/agent'
agent = Agent(bus, AGENT_PATH)
manager = dbus.Interface(bus.get_object('org.bluez', '/org/bluez'), 'org.bluez.AgentManager1')
try:
    manager.RegisterAgent(AGENT_PATH, 'NoInputNoOutput')
    manager.RequestDefaultAgent(AGENT_PATH)
    print('Agent registered')
except Exception as e:
    print('Agent register:', e)

def adapters():
    out = {}
    for path, ifaces in om.GetManagedObjects().items():
        a = ifaces.get('org.bluez.Adapter1')
        if a:
            out[str(a['Address'])] = path
    return out

def props(path, iface='org.bluez.Adapter1'):
    return dbus.Interface(bus.get_object('org.bluez', path), 'org.freedesktop.DBus.Properties')

def adapter_iface(path):
    return dbus.Interface(bus.get_object('org.bluez', path), 'org.bluez.Adapter1')

def device_iface(path):
    return dbus.Interface(bus.get_object('org.bluez', path), 'org.bluez.Device1')

def find_device(substr=None, mac=None):
    for path, ifaces in om.GetManagedObjects().items():
        d = ifaces.get('org.bluez.Device1')
        if not d:
            continue
        addr = str(d.get('Address', ''))
        name = str(d.get('Name') or d.get('Alias') or '')
        if mac and addr.upper() == mac.upper():
            return path, d
        if substr and substr.lower() in name.lower():
            return path, d
    return None, None

ads = adapters()
print('Adapters:', ads)
adapter_addr = USB if USB in ads else (INTEL if INTEL in ads else next(iter(ads)))
adapter_path = ads[adapter_addr]
print(f'Using adapter {adapter_addr} @ {adapter_path}')

ap = props(adapter_path)
ap.Set('org.bluez.Adapter1', 'Powered', dbus.Boolean(True))
ap.Set('org.bluez.Adapter1', 'Pairable', dbus.Boolean(True))
ai = adapter_iface(adapter_path)

found = {}

def on_added(path, interfaces):
    if 'org.bluez.Device1' in interfaces:
        d = interfaces['org.bluez.Device1']
        addr = str(d.get('Address', ''))
        name = str(d.get('Name') or d.get('Alias') or '')
        found[addr] = (path, name)
        print(f'FOUND {addr}  {name}', flush=True)

bus.add_signal_receiver(on_added, dbus_interface='org.freedesktop.DBus.ObjectManager', signal_name='InterfacesAdded')

try:
    ai.SetDiscoveryFilter(dbus.Dictionary({'Transport': dbus.String('auto'), 'DuplicateData': dbus.Boolean(True)}, signature='sv'))
except Exception as e:
    print('filter warn:', e)

print('Scanning 40s — ustaw Soundcore w tryb parowania...', flush=True)
ai.StartDiscovery()
loop = GLib.MainLoop()
GLib.timeout_add_seconds(40, loop.quit)
loop.run()
try:
    ai.StopDiscovery()
except Exception:
    pass

path, d = find_device(substr=TARGET_NAME_SUB)
if not path:
    path, d = find_device(mac=KNOWN_MAC)
if not path:
    # any audio-headset
    for p, ifaces in om.GetManagedObjects().items():
        dd = ifaces.get('org.bluez.Device1')
        if not dd:
            continue
        if str(dd.get('Icon') or '') == 'audio-headset' or 'sound' in str(dd.get('Name') or '').lower():
            path, d = p, dd
            break

if not path:
    print('FAIL: soundcore nie znaleziony')
    for a, (p, n) in found.items():
        print(' ', a, n)
    sys.exit(2)

addr = str(d.get('Address'))
name = str(d.get('Name') or d.get('Alias') or '')
print(f'Target: {name} ({addr}) path={path}')

# Prefer device under selected adapter path
if not path.startswith(adapter_path):
    print(f'UWAGA: urządzenie pod innym adapterem ({path}), próbuję i tak')

di = device_iface(path)
dp = props(path, 'org.bluez.Device1')
err = {'msg': None}
done = {'ok': False}

def get(key):
    return dp.Get('org.bluez.Device1', key)

try:
    dp.Set('org.bluez.Device1', 'Trusted', dbus.Boolean(True))
except Exception as e:
    print('trust:', e)

def on_ok(*_a):
    done['ok'] = True
    loop.quit()

def on_err(e):
    err['msg'] = str(e)
    print('ERR:', e, flush=True)
    loop.quit()

paired = bool(get('Paired'))
print('Already paired:', paired, flush=True)
if not paired:
    print('Pairing (async)...', flush=True)
    loop = GLib.MainLoop()
    di.Pair(reply_handler=on_ok, error_handler=on_err)
    GLib.timeout_add_seconds(60, loop.quit)
    loop.run()
    try:
        paired = bool(get('Paired'))
    except Exception:
        paired = False
    print('Paired:', paired, 'err:', err['msg'], flush=True)

print('Connecting (async)...', flush=True)
ok = False
for i in range(3):
    err['msg'] = None
    done['ok'] = False
    loop = GLib.MainLoop()
    di.Connect(reply_handler=on_ok, error_handler=on_err)
    GLib.timeout_add_seconds(45, loop.quit)
    loop.run()
    try:
        if bool(get('Connected')):
            ok = True
            break
    except Exception as e:
        print('get Connected:', e)
    print(f'Connect try {i+1} failed:', err['msg'])
    time.sleep(2)

time.sleep(1)
try:
    print('Connected:', bool(get('Connected')))
    print('Paired:', bool(get('Paired')))
    print('Trusted:', bool(get('Trusted')))
    print('Name:', get('Name'))
except Exception as e:
    print('final props:', e)

sys.exit(0 if ok else 1)
