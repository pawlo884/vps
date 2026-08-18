#!/bin/bash
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/1000
SINK=bluez_output.18_9C_2C_20_D5_B8.1

# reconnect sink name if needed
if ! pactl list short sinks | grep -q "$SINK"; then
  SINK=$(pactl list short sinks | awk '/bluez_output/{print $2; exit}')
fi
echo "sink=$SINK"
pactl set-default-sink "$SINK"
pactl set-sink-volume "$SINK" 85%

echo "1 bip"
ffmpeg -hide_banner -nostats -loglevel error -f lavfi -i sine=frequency=880:duration=1 -f pulse "$SINK"
sleep 0.5
echo "2 LEWY"
ffmpeg -hide_banner -nostats -loglevel error -f lavfi -i sine=frequency=440:duration=1.2 -af 'pan=stereo|c0=c0|c1=0*c0' -f pulse "$SINK"
sleep 0.5
echo "3 PRAWY"
ffmpeg -hide_banner -nostats -loglevel error -f lavfi -i sine=frequency=660:duration=1.2 -af 'pan=stereo|c0=0*c0|c1=c0' -f pulse "$SINK"
sleep 0.4
echo "4 OBA"
ffmpeg -hide_banner -nostats -loglevel error -f lavfi -i sine=frequency=520:duration=1 -f pulse "$SINK"
echo DONE
