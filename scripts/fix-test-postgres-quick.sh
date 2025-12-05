#!/bin/bash
# Szybka poprawka dla kontenera nc-postgres-test
# Dodaje ustawienia TCP keepalive bez konieczności pełnej migracji

set -e

CONTAINER="nc-postgres-test"

echo "=== Szybka poprawka kontenera $CONTAINER ==="
echo ""

# Sprawdź czy kontener istnieje
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "Kontener $CONTAINER nie istnieje."
    exit 1
fi

# Sprawdź czy kontener działa
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "Kontener nie działa. Uruchamiam..."
    docker start "$CONTAINER"
    echo "Czekam 5 sekund na uruchomienie..."
    sleep 5
fi

echo "Kontener działa. Pobieram konfigurację..."

# Pobierz użytkownika z kontenera
DB_USER=$(docker inspect "$CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E '^POSTGRES_USER=' | cut -d'=' -f2 || echo "postgres")

if [ -z "$DB_USER" ] || [ "$DB_USER" = "postgres" ]; then
    echo "Nie udało się określić użytkownika. Próbuję domyślnych wartości..."
    DB_USER="testuser"
fi

echo "Używam użytkownika: $DB_USER"
echo ""

# Sprawdź czy postgresql.conf istnieje w kontenerze
PGCONF="/var/lib/postgresql/data/postgresql.conf"
if docker exec "$CONTAINER" test -f "$PGCONF" 2>/dev/null; then
    echo "Znaleziono postgresql.conf w kontenerze."
    echo "Dodawanie ustawień TCP keepalive..."
    
    # Dodaj ustawienia do postgresql.conf
    docker exec "$CONTAINER" sh -c "
        # Backup oryginalnego pliku
        cp $PGCONF ${PGCONF}.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
        
        # Dodaj lub zaktualizuj ustawienia
        if grep -q '^tcp_keepalives_idle' $PGCONF 2>/dev/null; then
            sed -i 's/^#*tcp_keepalives_idle.*/tcp_keepalives_idle = 60/' $PGCONF
        else
            echo 'tcp_keepalives_idle = 60' >> $PGCONF
        fi
        
        if grep -q '^tcp_keepalives_interval' $PGCONF 2>/dev/null; then
            sed -i 's/^#*tcp_keepalives_interval.*/tcp_keepalives_interval = 10/' $PGCONF
        else
            echo 'tcp_keepalives_interval = 10' >> $PGCONF
        fi
        
        if grep -q '^tcp_keepalives_count' $PGCONF 2>/dev/null; then
            sed -i 's/^#*tcp_keepalives_count.*/tcp_keepalives_count = 5/' $PGCONF
        else
            echo 'tcp_keepalives_count = 5' >> $PGCONF
        fi
        
        if ! grep -q '^listen_addresses' $PGCONF 2>/dev/null; then
            echo \"listen_addresses = '*'\" >> $PGCONF
        fi
    "
    
    echo "Ustawienia dodane do postgresql.conf."
    echo "Restartowanie kontenera, aby zastosować zmiany..."
    docker restart "$CONTAINER"
    
    echo "Czekam 5 sekund na uruchomienie..."
    sleep 5
    
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        echo "✓ Kontener został zrestartowany pomyślnie."
    else
        echo "✗ Błąd: Kontener nie działa po restarcie!"
        exit 1
    fi
else
    echo "Nie znaleziono postgresql.conf. Próbuję dodać ustawienia przez ALTER SYSTEM..."
    
    # Dodaj ustawienia przez SQL (wymaga restartu bazy)
    docker exec "$CONTAINER" psql -U "$DB_USER" -d postgres <<EOF || echo "Nie udało się dodać ustawień przez SQL."
ALTER SYSTEM SET tcp_keepalives_idle = 60;
ALTER SYSTEM SET tcp_keepalives_interval = 10;
ALTER SYSTEM SET tcp_keepalives_count = 5;
ALTER SYSTEM SET listen_addresses = '*';
SELECT pg_reload_conf();
EOF
    
    echo ""
    echo "Ustawienia dodane przez ALTER SYSTEM."
    echo "UWAGA: Aby zastosować zmiany na stałe, konieczny jest restart kontenera:"
    echo "  docker restart $CONTAINER"
fi

echo ""
echo "=== Zakończono ==="
echo ""
echo "Ustawienia zostały dodane:"
echo "  - tcp_keepalives_idle = 60"
echo "  - tcp_keepalives_interval = 10"
echo "  - tcp_keepalives_count = 5"
echo "  - listen_addresses = '*'"
echo ""
echo "Aby sprawdzić ustawienia:"
echo "  docker exec $CONTAINER psql -U $DB_USER -d postgres -c \"SHOW tcp_keepalives_idle;\""
echo ""
echo "UWAGA: Dla pełnej optymalizacji (healthcheck, limity logowania, etc.)"
echo "zastanów się nad migracją do docker-compose:"
echo "  ~/vps/scripts/migrate-test-postgres.sh"




