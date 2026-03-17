#!/bin/bash
# Skrypt do usunięcia baz i przywrócenia z backupu z 2 w nocy (2025-12-03_02-00)
# Użycie: ssh user@vps 'bash -s' < scripts/restore-databases-from-backup.sh

set -e

BACKUP_DIR="/srv/backups/postgres/nc"
BACKUP_DATE="2025-12-03_02-00"
CONTAINER="nc-postgres-1"
DB_USER="pawel"

echo "=========================================="
echo "PRZYWRACANIE BAZ Z BACKUPU Z 2 W NOCY"
echo "Backup: $BACKUP_DATE"
echo "=========================================="
echo ""

# Lista baz do przywrócenia
DATABASES=("matterhorn1" "default" "MPD" "web_agent")

# Sprawdź czy kontener działa
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "❌ BŁĄD: Kontener $CONTAINER nie działa!"
    exit 1
fi

# Sprawdź czy backupy istnieją
echo "🔍 Sprawdzanie backupów..."
for db in "${DATABASES[@]}"; do
    BACKUP_FILE="${BACKUP_DIR}/${db}_${BACKUP_DATE}.sql.gz"
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "❌ BŁĄD: Backup nie istnieje: $BACKUP_FILE"
        exit 1
    fi
    echo "✅ Znaleziono: $BACKUP_FILE"
done
echo ""

# Usuń i utwórz bazy na nowo
echo "🗑️  Usuwanie i odtwarzanie baz..."
for db in "${DATABASES[@]}"; do
    echo ""
    echo "--- $db ---"
    
    # Zakończ wszystkie połączenia do bazy
    echo "  Zamykanie połączeń do bazy $db..."
    docker exec -t $CONTAINER psql -U $DB_USER -d postgres -c "
        SELECT pg_terminate_backend(pid) 
        FROM pg_stat_activity 
        WHERE datname = '$db' AND pid <> pg_backend_pid();
    " 2>/dev/null || true
    
    # Usuń bazę (używamy cudzysłowów dla nazw, które mogą być słowami kluczowymi)
    echo "  Usuwanie bazy $db..."
    docker exec -t $CONTAINER psql -U $DB_USER -d postgres -c "DROP DATABASE IF EXISTS \"$db\";" 2>/dev/null || true
    
    # Utwórz bazę na nowo (używamy cudzysłowów dla nazw, które mogą być słowami kluczowymi)
    echo "  Tworzenie bazy $db..."
    docker exec -t $CONTAINER psql -U $DB_USER -d postgres -c "CREATE DATABASE \"$db\" OWNER $DB_USER;" || {
        echo "  ❌ BŁĄD: Nie można utworzyć bazy $db"
        exit 1
    }
    
    # Przywróć z backupu
    BACKUP_FILE="${BACKUP_DIR}/${db}_${BACKUP_DATE}.sql.gz"
    echo "  Przywracanie z backupu: $BACKUP_FILE"
    gunzip -c "$BACKUP_FILE" | docker exec -i $CONTAINER psql -U $DB_USER -d $db || {
        echo "  ❌ BŁĄD: Nie można przywrócić bazy $db"
        exit 1
    }
    
    echo "  ✅ Baza $db przywrócona pomyślnie"
done

echo ""
echo "=========================================="
echo "✅ WSZYSTKIE BAZY PRZYWRÓCONE POMYŚLNIE"
echo "=========================================="
echo ""
echo "Przywrócone bazy:"
for db in "${DATABASES[@]}"; do
    echo "  - $db"
done
echo ""
echo "Z backupu: $BACKUP_DATE"

