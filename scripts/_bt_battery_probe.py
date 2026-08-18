#!/usr/bin/env python3
import dbus
bus = dbus.SystemBus()
om = dbus.Interface(bus.get_object('org.bluez', '/'), 'org.freedesktop.DBus.ObjectManager')
target = '18:9C:2C:20:D5:B8'
for path, ifaces in om.GetManagedObjects().items():
    d = ifaces.get('org.bluez.Device1')
    if d and str(d.get('Address')) == target:
        print('Device', path)
        print('  Connected:', bool(d.get('Connected')))
        print('  Name:', d.get('Name'))
        for k in sorted(d.keys()):
            if 'battery' in k.lower() or 'Battery' in k:
                print(f'  {k}:', d[k])
    if 'org.bluez.Battery1' in ifaces and target.replace(':', '_') in path:
        b = ifaces['org.bluez.Battery1']
        print('Battery1', path, dict(b))
    if path.endswith(target.replace(':', '_')) or f'dev_{target.replace(":", "_")}' in path:
        for iname in ifaces:
            if 'Battery' in iname or 'battery' in iname.lower():
                print('IFACE', iname, path, dict(ifaces[iname]))
# scan all Battery1
print('--- all Battery1 ---')
for path, ifaces in om.GetManagedObjects().items():
    if 'org.bluez.Battery1' in ifaces:
        print(path, dict(ifaces['org.bluez.Battery1']))
