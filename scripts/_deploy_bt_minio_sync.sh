#!/bin/bash
set -euo pipefail
USER=pawel
HOME_DIR=/home/$USER
BIN=$HOME_DIR/bin
UNIT_DIR=$HOME_DIR/.config/systemd/user
CFG_DIR=$HOME_DIR/.config
mkdir -p "$BIN" "$UNIT_DIR" "$CFG_DIR" "$HOME_DIR/.mc"

# credentials from running compose (no secrets in git)
ROOT_USER=$(docker inspect minio --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^MINIO_ROOT_USER=//p')
ROOT_PASS=$(docker inspect minio --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^MINIO_ROOT_PASSWORD=//p')
if [[ -z "$ROOT_USER" || -z "$ROOT_PASS" ]]; then
  echo "ERROR: nie mogę odczytać credentials MinIO z kontenera"
  exit 1
fi

cat > "$CFG_DIR/minio-sync.env" <<EOF
MINIO_ROOT_USER=${ROOT_USER}
MINIO_ROOT_PASSWORD=${ROOT_PASS}
MINIO_ENDPOINT=http://127.0.0.1:9100
MINIO_ALIAS=local
BUCKET=soundcore-recordings
SRC_DIR=${HOME_DIR}/Recordings/continuous
MC_BIN=${BIN}/mc
EOF
chown "$USER:$USER" "$CFG_DIR/minio-sync.env"
chmod 600 "$CFG_DIR/minio-sync.env"

# install mc binary if missing
if [[ ! -x "$BIN/mc" ]]; then
  echo "Pobieram mc..."
  curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc -o "$BIN/mc"
  chmod 755 "$BIN/mc"
  chown "$USER:$USER" "$BIN/mc"
fi

install -o "$USER" -g "$USER" -m 0755 /tmp/bt-minio-sync "$BIN/bt-minio-sync"
install -o "$USER" -g "$USER" -m 0644 /tmp/bt-minio-sync.service "$UNIT_DIR/bt-minio-sync.service"

# one-shot: create bucket + initial sync
export HOME="$HOME_DIR"
sudo -u "$USER" bash -c "
  source $CFG_DIR/minio-sync.env
  export MC_CONFIG_DIR=$HOME_DIR/.mc
  $BIN/mc alias set local http://127.0.0.1:9100 \"\$MINIO_ROOT_USER\" \"\$MINIO_ROOT_PASSWORD\"
  $BIN/mc mb --ignore-existing local/soundcore-recordings
  $BIN/mc mirror --overwrite --exclude 'recorder.log' --exclude 'test-vad/**' --exclude '*.log' \
    $HOME_DIR/Recordings/continuous/ local/soundcore-recordings/ || true
  $BIN/mc ls local/soundcore-recordings/
"

export XDG_RUNTIME_DIR=/run/user/1000
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
systemctl --user daemon-reload
systemctl --user enable --now bt-minio-sync.service
sleep 2
systemctl --user status bt-minio-sync.service --no-pager -l | head -20
echo "=== bucket ==="
sudo -u "$USER" HOME="$HOME_DIR" MC_CONFIG_DIR="$HOME_DIR/.mc" "$BIN/mc" ls local/soundcore-recordings/ || true
echo DONE
echo "Konsola MinIO: http://<vps>:9101  (user/hasło jak w stacku minio)"
echo "Bucket: soundcore-recordings"
