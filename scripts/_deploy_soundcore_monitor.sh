#!/bin/bash
set -euo pipefail
DEST=/home/pawel/stacks/soundcore-monitor
UNIT_DIR=/home/pawel/.config/systemd/user
mkdir -p "$DEST" "$UNIT_DIR"

cp /tmp/soundcore-monitor-app.py "$DEST/app.py"
cp /tmp/soundcore-monitor-requirements.txt "$DEST/requirements.txt"
cp /tmp/soundcore-monitor.service "$UNIT_DIR/soundcore-monitor.service"
chown -R pawel:pawel "$DEST" "$UNIT_DIR/soundcore-monitor.service"

apt-get install -y python3-dbus python3-gi >/dev/null

# recreate venv with system-site-packages (dbus)
rm -rf "$DEST/.venv"
sudo -u pawel python3 -m venv --system-site-packages "$DEST/.venv"
sudo -u pawel "$DEST/.venv/bin/pip" install -U pip
sudo -u pawel "$DEST/.venv/bin/pip" install -r "$DEST/requirements.txt"
sudo -u pawel "$DEST/.venv/bin/python" -c 'import dbus, streamlit; print("imports ok", streamlit.__version__)'

export XDG_RUNTIME_DIR=/run/user/1000
sudo -u pawel XDG_RUNTIME_DIR=/run/user/1000 systemctl --user daemon-reload
sudo -u pawel XDG_RUNTIME_DIR=/run/user/1000 systemctl --user enable --now soundcore-monitor.service
sleep 4
sudo -u pawel XDG_RUNTIME_DIR=/run/user/1000 systemctl --user status soundcore-monitor.service --no-pager | head -25
ss -tlnp | grep 8599 || true
curl -s -o /dev/null -w "http_code=%{http_code}\n" http://127.0.0.1:8599/ || true
echo "URL: http://212.127.93.27:8599"
