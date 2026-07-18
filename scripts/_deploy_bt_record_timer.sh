#!/bin/bash
set -euo pipefail
# Deploy recorder + mute now + enable timer for 06:00 PL (04:00 UTC)
USER=pawel
HOME_DIR=/home/$USER
BIN=$HOME_DIR/bin
UNIT_DIR=$HOME_DIR/.config/systemd/user
mkdir -p "$BIN" "$UNIT_DIR" "$HOME_DIR/Recordings/continuous"

install -m 0755 /tmp/bt-record-continuous "$BIN/bt-record-continuous"
install -m 0755 /tmp/bt-prep-record-only "$BIN/bt-prep-record-only"
install -m 0644 /tmp/bt-record-continuous.service "$UNIT_DIR/bt-record-continuous.service"
install -m 0644 /tmp/bt-record-continuous.timer "$UNIT_DIR/bt-record-continuous.timer"

# ensure linger for user timers without login
loginctl enable-linger "$USER" || true

export XDG_RUNTIME_DIR=/run/user/1000
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus

# stop if already running
systemctl --user stop bt-record-continuous.service 2>/dev/null || true

# prep: mute + HFP now
sudo -u "$USER" XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  "$BIN/bt-prep-record-only"

systemctl --user daemon-reload
systemctl --user enable bt-record-continuous.timer
systemctl --user start bt-record-continuous.timer
# do NOT start service now — only tomorrow 6:00

echo "=== timer ==="
systemctl --user list-timers bt-record-continuous.timer --all
systemctl --user status bt-record-continuous.timer --no-pager || true
echo "=== next ==="
systemctl --user show bt-record-continuous.timer -p NextElapseUSecRealtime -p Triggers
echo DONE
