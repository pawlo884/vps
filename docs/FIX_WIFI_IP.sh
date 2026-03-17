#!/bin/bash
# Naprawa konfiguracji WiFi - ustawienie statycznego IP 192.168.50.31
# Wykonaj na serwerze: sudo bash fix_wifi_ip.sh

echo "=== Naprawa konfiguracji WiFi ==="

# Sprawdź aktualny adres
echo "Aktualny adres IP:"
ip addr show wlp0s20f3 | grep 'inet '

# Znajdź plik netplan z konfiguracją WiFi
WIFI_CONFIG=$(ls /etc/netplan/*.yaml 2>/dev/null | head -1)

if [ -z "$WIFI_CONFIG" ]; then
    echo "Brak pliku konfiguracji netplan!"
    exit 1
fi

echo ""
echo "Plik konfiguracji: $WIFI_CONFIG"
echo ""
echo "=== Aktualna konfiguracja WiFi ==="
cat "$WIFI_CONFIG" | grep -A 20 'wlp0s20f3' || echo "Brak konfiguracji WiFi"

echo ""
echo "=== Tworzenie kopii zapasowej ==="
sudo cp "$WIFI_CONFIG" "${WIFI_CONFIG}.backup"

echo ""
echo "=== Aktualizacja konfiguracji ==="
# Sprawdź czy plik zawiera już konfigurację WiFi
if grep -q "wlp0s20f3" "$WIFI_CONFIG"; then
    echo "Znaleziono konfigurację WiFi - aktualizuję..."
    # Zaktualizuj adres IP w istniejącej konfiguracji
    sudo sed -i 's|addresses:.*192\.168\.50\.[0-9]*/24|addresses:\n        - 192.168.50.31/24|' "$WIFI_CONFIG"
else
    echo "Dodaję konfigurację WiFi..."
    # Dodaj konfigurację WiFi (wymaga ręcznej edycji)
    echo "UWAGA: Wymagana ręczna edycja pliku $WIFI_CONFIG"
    echo "Dodaj sekcję:"
    echo ""
    echo "wifis:"
    echo "  wlp0s20f3:"
    echo "    dhcp4: false"
    echo "    addresses:"
    echo "      - 192.168.50.31/24"
    echo "    routes:"
    echo "      - to: default"
    echo "        via: 192.168.50.1"
    echo "    nameservers:"
    echo "      addresses:"
    echo "        - 1.1.1.1"
    echo "        - 8.8.8.8"
    echo "    access-points:"
    echo "      \"Loki\":"
    echo "        password: \"staropolanka2000\""
fi

echo ""
echo "=== Zastosowanie konfiguracji ==="
echo "Aby zastosować zmiany, wykonaj:"
echo "  sudo netplan apply"
echo ""
echo "Lub użyj Ansible:"
echo "  cd ~/vps/ansible"
echo "  ansible-playbook playbooks/wifi-only.yml"

