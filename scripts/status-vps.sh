#!/bin/bash
# Sprawdzenie statusu VPS - podstawowe informacje

cd "$(dirname "$0")/.." || exit 1

# Aktywuj lokalny venv, jeśli istnieje (Windows Git Bash)
if [ -f .venv/Scripts/activate ]; then
  # shellcheck disable=SC1091
  source .venv/Scripts/activate
fi

echo "📊 Status VPS"
echo "=============="
echo ""

# Sprawdź czy ansible jest zainstalowany
if ! command -v ansible &> /dev/null; then
    echo "❌ Ansible nie jest zainstalowany!"
    exit 1
fi

cd ansible || exit 1

echo "🖥️  System:"
ansible all -m setup -a "gather_subset=min" | grep -E "ansible_distribution|ansible_distribution_version|ansible_processor_vcpus|ansible_memtotal_mb" | head -4

echo ""
echo "💾 Dysk:"
ansible all -m shell -a "df -h /" | tail -1

echo ""
echo "🐳 Docker:"
ansible all -m shell -a "docker --version 2>/dev/null || echo 'Docker nie zainstalowany'" | grep -v "vps | SUCCESS"

echo ""
echo "🔌 Uruchomione kontenery:"
ansible all -m shell -a "docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null || echo 'Brak kontenerów'" | grep -v "vps | SUCCESS"

echo ""
echo "🌐 Nginx:"
ansible all -m shell -a "systemctl is-active nginx 2>/dev/null || echo 'Nginx nieaktywny'" | grep -v "vps | SUCCESS"

echo ""
echo "🔥 Firewall:"
ansible all -m shell -a "sudo ufw status | head -5" | grep -v "vps | SUCCESS"

echo ""
echo "✅ Zakończono!"

