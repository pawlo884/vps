#!/bin/bash
# Przełącza Soundcore Q11i na HFP (mikrofon) i nagrywa test.
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/1000
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
MAC_PATH=/org/bluez/hci0/dev_18_9C_2C_20_D5_B8
CARD=bluez_card.18_9C_2C_20_D5_B8
OUT_DIR=/home/pawel/Recordings
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/bt-mic-$(date +%Y%m%d-%H%M%S).wav"

echo "=== reconnect BT ==="
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
    loop=GLib.MainLoop(); err=[None]
    di.Connect(reply_handler=lambda *a: loop.quit(), error_handler=lambda e:(err.__setitem__(0,str(e)), loop.quit()))
    GLib.timeout_add_seconds(40, loop.quit); loop.run()
    time.sleep(2)
    print('connect err', err[0])
print('Connected', bool(dp.Get('org.bluez.Device1','Connected')))
PY

sleep 2
echo "=== switch to HFP mic profile (msbc) ==="
# A2DP = tylko odtwarzanie. Mikrofon wymaga HSP/HFP.
for prof in headset-head-unit-msbc headset-head-unit-cvsd headset-head-unit; do
  echo "try profile $prof"
  if pactl set-card-profile "$CARD" "$prof" 2>/dev/null; then
    sleep 2
    ACTIVE=$(pactl list cards | awk -v c="$CARD" '$0 ~ "Name: "c {f=1} f && /Active Profile:/ {print $3; exit}')
    echo "active=$ACTIVE"
    SRC=$(pactl list short sources | awk '/bluez_input/{print $2; exit}')
    echo "source=$SRC"
    if [[ -n "${SRC:-}" ]]; then
      break
    fi
  fi
done

echo "=== sources/sinks ==="
pactl list short sources
pactl list short sinks
pactl list cards | grep -A30 "Name: $CARD" | head -35

SRC=$(pactl list short sources | awk '/bluez_input/{print $2; exit}')
if [[ -z "${SRC:-}" ]]; then
  echo "FAIL: brak bluez_input — HFP nie wstał"
  echo "Dostępne źródła:"
  pactl list short sources
  # fallback: nagraj z wbudowanego MIC ProDeska
  SRC=$(pactl list short sources | awk '/alsa_input/{print $2; exit}')
  echo "FALLBACK alsa: $SRC"
  if [[ -z "${SRC:-}" ]]; then
    exit 2
  fi
  OUT="$OUT_DIR/alsa-mic-$(date +%Y%m%d-%H%M%S).wav"
fi

pactl set-default-source "$SRC" || true
pactl set-source-mute "$SRC" 0 || true
pactl set-source-volume "$SRC" 100% || true

echo "=== NAGRYWANIE 5s z: $SRC ==="
echo "Mów teraz do mikrofonu słuchawek..."
ffmpeg -y -hide_banner -loglevel error -f pulse -i "$SRC" -t 5 -ac 1 -ar 16000 "$OUT"
ls -lh "$OUT"
echo "OUT=$OUT"

# szybkie odtworzenie na A2DP jeśli możliwe (żeby usłyszeć nagranie)
echo "=== przełączam na A2DP i odtwarzam nagranie ==="
pactl set-card-profile "$CARD" a2dp-sink 2>/dev/null || true
sleep 2
SINK=$(pactl list short sinks | awk '/bluez_output/{print $2; exit}')
if [[ -n "${SINK:-}" ]]; then
  pactl set-default-sink "$SINK"
  pactl set-sink-volume "$SINK" 100%
  # upsample for playback
  ffmpeg -y -hide_banner -loglevel error -i "$OUT" -ar 44100 -ac 2 /tmp/rec-play.wav
  paplay --device="$SINK" /tmp/rec-play.wav || paplay /tmp/rec-play.wav || true
fi
echo DONE
