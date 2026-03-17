#!/bin/bash
# Skrypt weryfikacyjny po deploymencie Ansible

set -e

cd "$(dirname "$0")/.." || exit 1

echo "🔍 Weryfikacja deploymentu VPS"
echo "================================"
echo ""

cd ansible || exit 1

echo "📦 Kontenery Docker:"
ansible all -m shell -a "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" 2>/dev/null || echo "Błąd - sprawdź czy Docker działa"

echo ""
echo "🗄️  PostgreSQL kontenery:"
ansible all -m shell -a "docker ps --filter 'name=postgres' --format 'table {{.Names}}\t{{.Status}}'" 2>/dev/null || echo "Brak kontenerów PostgreSQL"

echo ""
echo "📊 Netdata:"
ansible all -m shell -a "docker ps --filter 'name=netdata' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" 2>/dev/null || echo "Netdata nie uruchomiony"

echo ""
echo "💾 Katalogi PostgreSQL:"
ansible all -m shell -a "ls -ld /srv/postgres/*/data /srv/postgres/*/backups 2>/dev/null | head -10" 2>/dev/null || echo "Brak katalogów"

echo ""
echo "🔄 Crony backupów:"
ansible all -m shell -a "crontab -l 2>/dev/null | grep pg_backup || echo 'Brak cronów backupów'" 2>/dev/null

echo ""
echo "⚙️  Docker daemon.json:"
ansible all -m shell -a "cat /etc/docker/daemon.json 2>/dev/null || echo 'Brak konfiguracji'" 2>/dev/null

echo ""
echo "📝 Sysctl vm.swappiness:"
ansible all -m shell -a "sysctl vm.swappiness" 2>/dev/null

echo ""
echo "✅ Weryfikacja zakończona!"

