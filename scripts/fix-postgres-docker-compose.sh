#!/bin/bash
# Skrypt do naprawy problemu z długimi połączeniami do PostgreSQL
# Dodaje ustawienia keepalive do docker-compose.yml lub bezpośrednio do kontenerów

set -e

CONTAINERS=("nc-postgres-1" "nc-postgres-test")

echo "=== Naprawa problemu z długimi połączeniami do PostgreSQL ==="
echo ""

for CONTAINER in "${CONTAINERS[@]}"; do
    echo "=== Kontener: $CONTAINER ==="
    
    # Sprawdź czy kontener istnieje
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        echo "Kontener $CONTAINER nie istnieje. Pomijam."
        echo ""
        continue
    fi
    
    # Sprawdź czy kontener działa
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        echo "Kontener $CONTAINER nie działa. Uruchamiam..."
        docker start "$CONTAINER"
        sleep 2
    fi
    
    echo "Kontener $CONTAINER działa."
    
    # Sprawdź czy ustawienia już istnieją w command
    CURRENT_CMD=$(docker inspect "$CONTAINER" --format '{{json .Args}}' 2>/dev/null || echo "[]")
    
    if echo "$CURRENT_CMD" | grep -q "tcp_keepalives"; then
        echo "Ustawienia keepalive już istnieją w kontenerze $CONTAINER."
    else
        echo "Dodawanie ustawień keepalive do kontenera $CONTAINER..."
        
        # Pobierz aktualną konfigurację kontenera
        CONTAINER_JSON=$(docker inspect "$CONTAINER")
        
        # Sprawdź czy kontener ma command override
        # Jeśli tak, musimy dodać parametry do istniejącego command
        # Jeśli nie, możemy dodać przez docker update (ale to nie zadziała dla command)
        
        # Najlepszym rozwiązaniem jest dodanie ustawień przez ALTER SYSTEM
        # lub przez modyfikację postgresql.conf
        
        echo "Dodawanie ustawień do postgresql.conf..."
        
        # Znajdź postgresql.conf
        PGDATA=$(docker inspect "$CONTAINER" --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Source}}{{end}}{{end}}')
        
        if [ -z "$PGDATA" ]; then
            # Spróbuj znaleźć przez docker exec
            PGCONF=$(docker exec "$CONTAINER" find /var/lib/postgresql -name "postgresql.conf" 2>/dev/null | head -1)
        else
            PGCONF="$PGDATA/postgresql.conf"
        fi
        
        if [ -n "$PGCONF" ] && docker exec "$CONTAINER" test -f "$PGCONF" 2>/dev/null; then
            echo "Znaleziono postgresql.conf: $PGCONF"
            
            # Dodaj ustawienia jeśli nie istnieją
            docker exec "$CONTAINER" sh -c "
                if ! grep -q '^listen_addresses' $PGCONF 2>/dev/null; then
                    echo \"listen_addresses = '*'\" >> $PGCONF
                else
                    sed -i \"s/^#*listen_addresses.*/listen_addresses = '*'/\" $PGCONF
                fi
                
                if ! grep -q '^tcp_keepalives_idle' $PGCONF 2>/dev/null; then
                    echo \"tcp_keepalives_idle = 600\" >> $PGCONF
                else
                    sed -i \"s/^#*tcp_keepalives_idle.*/tcp_keepalives_idle = 600/\" $PGCONF
                fi
                
                if ! grep -q '^tcp_keepalives_interval' $PGCONF 2>/dev/null; then
                    echo \"tcp_keepalives_interval = 30\" >> $PGCONF
                else
                    sed -i \"s/^#*tcp_keepalives_interval.*/tcp_keepalives_interval = 30/\" $PGCONF
                fi
                
                if ! grep -q '^tcp_keepalives_count' $PGCONF 2>/dev/null; then
                    echo \"tcp_keepalives_count = 3\" >> $PGCONF
                else
                    sed -i \"s/^#*tcp_keepalives_count.*/tcp_keepalives_count = 3/\" $PGCONF
                fi
            "
            
            echo "Ustawienia dodane. Restartowanie kontenera..."
            docker restart "$CONTAINER"
            
            echo "Czekam 5 sekund na uruchomienie..."
            sleep 5
            
            if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
                echo "✓ Kontener $CONTAINER został zrestartowany pomyślnie."
            else
                echo "✗ Błąd: Kontener $CONTAINER nie działa po restarcie!"
            fi
        else
            echo "Nie znaleziono postgresql.conf. Próbuję dodać ustawienia przez ALTER SYSTEM..."
            
            # Spróbuj dodać przez SQL
            DB_USER=$(docker inspect "$CONTAINER" --format '{{index .Config.Env}}' | grep -oP 'POSTGRES_USER=\K[^\s]+' || echo "postgres")
            
            docker exec "$CONTAINER" psql -U "$DB_USER" -d postgres -c "
                ALTER SYSTEM SET listen_addresses = '*';
                ALTER SYSTEM SET tcp_keepalives_idle = 600;
                ALTER SYSTEM SET tcp_keepalives_interval = 30;
                ALTER SYSTEM SET tcp_keepalives_count = 3;
            " 2>/dev/null || echo "Nie udało się dodać ustawień przez SQL. Może wymagać restartu kontenera z nowymi parametrami."
        fi
    fi
    
    echo ""
done

echo "=== Zakończono ==="
echo ""
echo "Ustawienia zostały dodane:"
echo "  - listen_addresses = '*'"
echo "  - tcp_keepalives_idle = 600"
echo "  - tcp_keepalives_interval = 30"
echo "  - tcp_keepalives_count = 3"
echo ""
echo "UWAGA: Jeśli kontenery są zarządzane przez docker-compose,"
echo "lepiej dodać te ustawienia bezpośrednio do pliku docker-compose.yml"
echo "w sekcji command, aby przetrwały restart kontenerów."




