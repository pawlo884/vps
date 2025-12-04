#!/bin/bash
# Skrypt do sprawdzania backupów - do uruchomienia BEZPOŚREDNIO na serwerze VPS
# Użycie: ssh user@vps 'bash -s' < scripts/check-backups-direct.sh

set -e

echo "🔍 SPRAWDZANIE BACKUPÓW BAZ DANYCH"
echo "==================================="
echo ""

BACKUP_DIR="/srv/backups/postgres/nc"
TEST_BACKUP_DIR="/srv/postgres/test/backups"

echo "📁 Sprawdzanie katalogu backupów produkcyjnych: $BACKUP_DIR"
if [ -d "$BACKUP_DIR" ]; then
    echo "✅ Katalog istnieje"
    echo ""
    echo "📊 Wszystkie backupy (sortowane po dacie):"
    ls -lth "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -30 || echo "Brak plików backupów"
    echo ""
    echo "📋 Backupy per baza danych:"
    for db in matterhorn1 default MPD web_agent; do
        echo ""
        echo "--- $db ---"
        ls -lth "$BACKUP_DIR/${db}_"*.sql.gz 2>/dev/null | head -5 || echo "BRAK backupów dla $db"
    done
    echo ""
    echo "📅 Ostatnie backupy (ostatnie 10 plików):"
    find "$BACKUP_DIR" -type f -name "*.sql.gz" -printf '%T@ %Tb %Td %TH:%TM %p\n' 2>/dev/null | sort -rn | head -10 | awk '{print $2" "$3" "$4" "$5}'
else
    echo "❌ Katalog $BACKUP_DIR nie istnieje!"
fi

echo ""
echo "📁 Sprawdzanie katalogu backupów testowych: $TEST_BACKUP_DIR"
if [ -d "$TEST_BACKUP_DIR" ]; then
    echo "✅ Katalog istnieje"
    ls -lth "$TEST_BACKUP_DIR"/*.sql.gz 2>/dev/null | head -10 || echo "Brak plików backupów"
else
    echo "ℹ️  Katalog testowy nie istnieje (to OK jeśli nie używasz testów)"
fi

echo ""
echo "⏰ Sprawdzanie cronów backupów:"
crontab -l 2>/dev/null | grep -E 'pg_backup|PostgreSQL backup' || echo "Brak cronów backupów"

echo ""
echo "📝 Sprawdzanie logów backupów:"
if [ -d "/home/pawel/logs/pg_backups" ]; then
    echo "Ostatnie logi:"
    ls -lth /home/pawel/logs/pg_backups/*.log 2>/dev/null | head -5
    echo ""
    echo "Ostatnie wpisy w logach:"
    tail -30 /home/pawel/logs/pg_backups/*.log 2>/dev/null | tail -20 || echo "Brak logów"
else
    echo "Katalog logów nie istnieje"
fi

echo ""
echo "🐳 Sprawdzanie kontenerów PostgreSQL:"
docker ps --filter 'name=postgres' --format 'table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}' 2>/dev/null || echo "Brak kontenerów PostgreSQL"

echo ""
echo "✅ Sprawdzanie zakończone!"



