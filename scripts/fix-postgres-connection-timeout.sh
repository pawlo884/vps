#!/bin/bash
# Skrypt do naprawy problemu z długimi połączeniami do PostgreSQL
# Dodaje ustawienia keepalive i listen_addresses do postgresql.conf

set -e

CONTAINERS=("nc-postgres-1" "nc-postgres-test")

for CONTAINER in "${CONTAINERS[@]}"; do
    echo "=== Sprawdzanie kontenera: $CONTAINER ==="
    
    # Sprawdź czy kontener istnieje i działa
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        echo "Kontener $CONTAINER nie istnieje lub nie działa. Pomijam."
        continue
    fi
    
    echo "Kontener $CONTAINER działa. Sprawdzam konfigurację..."
    
    # Sprawdź czy plik postgresql.conf istnieje
    PGCONF="/var/lib/postgresql/data/postgresql.conf"
    if ! docker exec "$CONTAINER" test -f "$PGCONF"; then
        # Spróbuj znaleźć postgresql.conf
        PGCONF=$(docker exec "$CONTAINER" find /var/lib/postgresql -name "postgresql.conf" 2>/dev/null | head -1)
        if [ -z "$PGCONF" ]; then
            echo "Nie znaleziono postgresql.conf w kontenerze $CONTAINER. Pomijam."
            continue
        fi
    fi
    
    echo "Znaleziono postgresql.conf: $PGCONF"
    
    # Sprawdź czy ustawienia już istnieją
    if docker exec "$CONTAINER" grep -q "^listen_addresses" "$PGCONF" 2>/dev/null; then
        echo "Ustawienie listen_addresses już istnieje. Aktualizuję..."
        docker exec "$CONTAINER" sed -i "s/^#*listen_addresses.*/listen_addresses = '*'/" "$PGCONF"
    else
        echo "Dodaję ustawienie listen_addresses..."
        docker exec "$CONTAINER" sh -c "echo \"listen_addresses = '*'\" >> $PGCONF"
    fi
    
    if docker exec "$CONTAINER" grep -q "^tcp_keepalives_idle" "$PGCONF" 2>/dev/null; then
        echo "Ustawienie tcp_keepalives_idle już istnieje. Aktualizuję..."
        docker exec "$CONTAINER" sed -i "s/^#*tcp_keepalives_idle.*/tcp_keepalives_idle = 600/" "$PGCONF"
    else
        echo "Dodaję ustawienie tcp_keepalives_idle..."
        docker exec "$CONTAINER" sh -c "echo \"tcp_keepalives_idle = 600\" >> $PGCONF"
    fi
    
    if docker exec "$CONTAINER" grep -q "^tcp_keepalives_interval" "$PGCONF" 2>/dev/null; then
        echo "Ustawienie tcp_keepalives_interval już istnieje. Aktualizuję..."
        docker exec "$CONTAINER" sed -i "s/^#*tcp_keepalives_interval.*/tcp_keepalives_interval = 30/" "$PGCONF"
    else
        echo "Dodaję ustawienie tcp_keepalives_interval..."
        docker exec "$CONTAINER" sh -c "echo \"tcp_keepalives_interval = 30\" >> $PGCONF"
    fi
    
    if docker exec "$CONTAINER" grep -q "^tcp_keepalives_count" "$PGCONF" 2>/dev/null; then
        echo "Ustawienie tcp_keepalives_count już istnieje. Aktualizuję..."
        docker exec "$CONTAINER" sed -i "s/^#*tcp_keepalives_count.*/tcp_keepalives_count = 3/" "$PGCONF"
    else
        echo "Dodaję ustawienie tcp_keepalives_count..."
        docker exec "$CONTAINER" sh -c "echo \"tcp_keepalives_count = 3\" >> $PGCONF"
    fi
    
    echo "Konfiguracja zaktualizowana. Restartowanie kontenera $CONTAINER..."
    docker restart "$CONTAINER"
    
    echo "Czekam 5 sekund na uruchomienie kontenera..."
    sleep 5
    
    # Sprawdź czy kontener działa
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        echo "✓ Kontener $CONTAINER został zrestartowany pomyślnie."
    else
        echo "✗ Błąd: Kontener $CONTAINER nie działa po restarcie!"
    fi
    
    echo ""
done

echo "=== Zakończono ==="
echo ""
echo "Ustawienia zostały dodane do postgresql.conf:"
echo "  - listen_addresses = '*'"
echo "  - tcp_keepalives_idle = 600"
echo "  - tcp_keepalives_interval = 30"
echo "  - tcp_keepalives_count = 3"
echo ""
echo "Te ustawienia powinny rozwiązać problem z długimi połączeniami."




