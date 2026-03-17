#!/bin/bash
# Skrypt do konfiguracji auto-login dla użytkownika pawel
# Wykonaj na serwerze: sudo bash auto_login_setup.sh

echo "=== Konfiguracja auto-login ==="

# Utwórz katalog dla override
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d

# Utwórz plik konfiguracyjny
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pawel --noclear %I $TERM
EOF

# Przeładuj systemd
sudo systemctl daemon-reload

echo "✅ Auto-login skonfigurowany"
echo ""
echo "=== Sprawdzanie konfiguracji ==="
cat /etc/systemd/system/getty@tty1.service.d/autologin.conf
echo ""
echo "=== Test ==="
echo "Aby przetestować, wykonaj: sudo systemctl restart getty@tty1.service"
echo "Lub zrestartuj serwer - po restarcie użytkownik 'pawel' zostanie automatycznie zalogowany"

