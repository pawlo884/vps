#!/bin/bash
# Skrypt do sprawdzania stanu backupów bazy danych

set -e

cd "$(dirname "$0")/.." || exit 1

echo "🔍 Sprawdzanie backupów bazy danych"
echo "==================================="
echo ""

cd ansible || exit 1

echo "📋 Skrypty backupowe na serwerze:"
ansible all -m shell -a "ls -lh /usr/local/bin/pg_backup_*.sh 2>/dev/null || echo 'Brak skryptów backupowych'" 2>/dev/null

echo ""
echo "⏰ Crony backupów:"
ansible all -m shell -a "crontab -l 2>/dev/null | grep -E 'pg_backup|PostgreSQL backup' || echo 'Brak cronów backupów'" 2>/dev/null

echo ""
echo "📁 Katalogi backupów:"
ansible all -m shell -a "ls -ld /srv/backups/postgres/* /srv/postgres/*/backups 2>/dev/null | head -20" 2>/dev/null || echo "Brak katalogów backupów"

echo ""
echo "💾 Pliki backupów (ostatnie 10):"
ansible all -m shell -a "find /srv/backups/postgres -type f -name '*.sql.gz' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -10 | awk '{print \$2}' | xargs -I {} ls -lh {} 2>/dev/null || echo 'Brak plików backupów w /srv/backups/postgres'" 2>/dev/null

ansible all -m shell -a "find /srv/postgres -type f -name '*.sql.gz' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -10 | awk '{print \$2}' | xargs -I {} ls -lh {} 2>/dev/null || echo 'Brak plików backupów w /srv/postgres'" 2>/dev/null

echo ""
echo "📝 Logi backupów:"
ansible all -m shell -a "ls -lh /home/pawel/logs/pg_backups/*.log 2>/dev/null | tail -10 || echo 'Brak logów backupów'" 2>/dev/null

echo ""
echo "📊 Ostatnie wpisy w logach (ostatnie 20 linii):"
ansible all -m shell -a "tail -20 /home/pawel/logs/pg_backups/*.log 2>/dev/null || echo 'Brak logów'" 2>/dev/null

echo ""
echo "🐳 Kontenery PostgreSQL (sprawdzanie czy działają):"
ansible all -m shell -a "docker ps --filter 'name=postgres' --format 'table {{.Names}}\t{{.Status}}'" 2>/dev/null || echo "Brak kontenerów PostgreSQL"

echo ""
echo "✅ Sprawdzanie zakończone!"
echo ""
echo "💡 Aby uruchomić backup ręcznie:"
echo "   ansible all -m shell -a '/usr/local/bin/pg_backup_NazwaBazy.sh'"
echo ""
echo "💡 Aby sprawdzić ostatni backup konkretnej bazy:"
echo "   ansible all -m shell -a 'ls -lth /srv/backups/postgres/nc/*.sql.gz | head -5'"

