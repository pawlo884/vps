#!/bin/bash
# Bezpośrednia migracja kontenera nc-postgres-test
# Uruchom na serwerze, gdzie kontener faktycznie działa

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   BEZPOŚREDNIA MIGRACJA: nc-postgres-test (OPCJA 2)       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

CONTAINER="nc-postgres-test"
COMPOSE_DIR="$HOME/vps/stacks/test-postgres"

# Funkcja sprawdzająca czy kontener istnieje
check_container() {
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
        return 0
    else
        return 1
    fi
}

# Sprawdź czy kontener istnieje
echo "🔍 Szukanie kontenera '$CONTAINER'..."
echo ""

if check_container; then
    echo "✅ Kontener znaleziony!"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep "$CONTAINER"
else
    echo "❌ Kontener '$CONTAINER' nie został znaleziony w tym środowisku Docker."
    echo ""
    echo "Możliwe przyczyny:"
    echo "  • Kontener jest na innym hoście Docker"
    echo "  • Portainer łączy się z innym serwerem"
    echo "  • Kontener ma inną nazwę"
    echo ""
    echo "📋 Wszystkie kontenery PostgreSQL:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep -i postgres || echo "   Brak kontenerów PostgreSQL"
    echo ""
    echo "💡 Rozwiązanie:"
    echo "  1. Połącz się BEZPOŚREDNIO z serwerem, gdzie kontener działa"
    echo "  2. Lub uruchom migrację przez Portainer (exec w kontenerze)"
    echo ""
    exit 1
fi

echo ""
echo "────────────────────────────────────────────────────────────────"
echo "📊 INFORMACJE O KONTENERZE:"
echo "────────────────────────────────────────────────────────────────"

# Pobierz szczegóły
STATUS=$(docker inspect "$CONTAINER" --format '{{.State.Status}}' 2>/dev/null)
IMAGE=$(docker inspect "$CONTAINER" --format '{{.Config.Image}}' 2>/dev/null)
CREATED=$(docker inspect "$CONTAINER" --format '{{.Created}}' 2>/dev/null)

echo "   Status: $STATUS"
echo "   Obraz: $IMAGE"
echo "   Utworzony: $CREATED"
echo ""

# Sprawdź volume
echo "🔍 Sprawdzanie volume z danymi..."
VOLUME_NAME=$(docker inspect "$CONTAINER" --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{end}}{{end}}' 2>/dev/null | head -1)

if [ -n "$VOLUME_NAME" ]; then
    echo "   ✅ Volume: $VOLUME_NAME"
    VOLUME_EXISTS=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -c "^${VOLUME_NAME}$" || echo "0")
    if [ "$VOLUME_EXISTS" -gt "0" ]; then
        echo "   ✅ Volume istnieje - dane będą zachowane!"
    fi
else
    echo "   ⚠️  Nie znaleziono volume. Sprawdzam bind mounty..."
    BIND_MOUNT=$(docker inspect "$CONTAINER" --format '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}} -> {{.Destination}}{{end}}{{end}}' 2>/dev/null | head -1)
    if [ -n "$BIND_MOUNT" ]; then
        echo "   ✅ Bind mount: $BIND_MOUNT"
    else
        echo "   ⚠️  Nie znaleziono mountu - kontener może nie mieć danych"
    fi
fi

echo ""

# Sprawdź czy pliki konfiguracyjne istnieją
if [ ! -d "$COMPOSE_DIR" ]; then
    echo "⚠️  Katalog $COMPOSE_DIR nie istnieje."
    echo "   Tworzenie katalogu..."
    mkdir -p "$COMPOSE_DIR"
fi

if [ ! -f "$COMPOSE_DIR/docker-compose.yml" ]; then
    echo "❌ BŁĄD: Brak pliku docker-compose.yml"
    echo "   Sprawdź czy pliki zostały skopiowane do: $COMPOSE_DIR"
    exit 1
fi

if [ ! -f "$COMPOSE_DIR/postgresql.conf" ]; then
    echo "❌ BŁĄD: Brak pliku postgresql.conf"
    echo "   Sprawdź czy pliki zostały skopiowane do: $COMPOSE_DIR"
    exit 1
fi

echo "✅ Pliki konfiguracyjne są dostępne"
echo ""

# Zapytaj o backup
echo "────────────────────────────────────────────────────────────────"
echo "💾 BACKUP DANYCH (ZALECANE):"
echo "────────────────────────────────────────────────────────────────"
echo ""
read -p "Czy chcesz zrobić backup przed migracją? (Y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    BACKUP_FILE="postgres_test_backup_$(date +%Y%m%d_%H%M%S).sql"
    echo "📦 Tworzenie backupu..."
    
    if [ "$STATUS" != "running" ]; then
        echo "   Uruchamianie kontenera do backupu..."
        docker start "$CONTAINER"
        sleep 3
    fi
    
    # Spróbuj zrobić backup
    DB_USER=$(docker inspect "$CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -E '^POSTGRES_USER=' | cut -d'=' -f2 || echo "testuser")
    
    echo "   Tworzenie backupu bazy danych (użytkownik: $DB_USER)..."
    if docker exec "$CONTAINER" pg_dumpall -U "$DB_USER" > "$BACKUP_FILE" 2>/dev/null; then
        echo "   ✅ Backup utworzony: $BACKUP_FILE"
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        echo "   Rozmiar: $BACKUP_SIZE"
    else
        echo "   ⚠️  Nie udało się utworzyć backupu SQL"
        echo "   Próbuję backup volume..."
        if [ -n "$VOLUME_NAME" ]; then
            VOLUME_BACKUP="${VOLUME_NAME}_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
            docker run --rm -v "$VOLUME_NAME":/data -v "$(pwd)":/backup alpine tar czf /backup/"$VOLUME_BACKUP" /data 2>/dev/null && \
                echo "   ✅ Backup volume utworzony: $VOLUME_BACKUP" || \
                echo "   ⚠️  Nie udało się utworzyć backupu volume"
        fi
    fi
    echo ""
fi

# Zatrzymaj kontener
if [ "$STATUS" = "running" ]; then
    echo "🛑 Zatrzymywanie kontenera..."
    docker stop "$CONTAINER" || {
        echo "❌ Nie udało się zatrzymać kontenera!"
        exit 1
    }
    echo "✅ Kontener zatrzymany"
    echo ""
fi

# Usuń kontener
echo "🗑️  Usuwanie starego kontenera..."
read -p "Czy na pewno chcesz usunąć kontener '$CONTAINER'? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Migracja anulowana. Kontener pozostaje zatrzymany."
    echo "   Możesz go uruchomić: docker start $CONTAINER"
    exit 0
fi

docker rm "$CONTAINER" || {
    echo "❌ Nie udało się usunąć kontenera!"
    exit 1
}
echo "✅ Stary kontener usunięty"
echo ""

# Sprawdź konfigurację docker-compose
echo "────────────────────────────────────────────────────────────────"
echo "⚙️  PRZYGOTOWANIE NOWEJ KONFIGURACJI:"
echo "────────────────────────────────────────────────────────────────"
echo ""

cd "$COMPOSE_DIR" || exit 1

# Jeśli volume ma inną nazwę, zaktualizuj docker-compose.yml
if [ -n "$VOLUME_NAME" ] && [ "$VOLUME_NAME" != "nc_postgres_test_data" ]; then
    echo "⚠️  Kontener używał volume: $VOLUME_NAME"
    echo "   Zaktualizuj docker-compose.yml, aby używał tego volume."
    echo ""
    read -p "Czy chcesz teraz zaktualizować docker-compose.yml? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sed -i "s/nc_postgres_test_data:/${VOLUME_NAME}:/g" docker-compose.yml
        echo "✅ docker-compose.yml zaktualizowany"
    fi
fi

# Sprawdź hasło
echo "📝 Sprawdź hasło w docker-compose.yml (linia 9):"
grep -n "POSTGRES_PASSWORD" docker-compose.yml || echo "   Nie znaleziono hasła w pliku"
echo ""

read -p "Czy hasło jest poprawne w docker-compose.yml? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "⚠️  Edytuj hasło w docker-compose.yml przed uruchomieniem:"
    echo "   nano docker-compose.yml"
    echo ""
    read -p "Naciśnij Enter po edycji hasła..." 
fi

# Uruchom nowy kontener
echo ""
echo "────────────────────────────────────────────────────────────────"
echo "🚀 URUCHAMIANIE NOWEGO KONTENERA:"
echo "────────────────────────────────────────────────────────────────"
echo ""

echo "Uruchamianie docker compose..."
docker compose up -d

echo ""
echo "⏳ Czekam 5 sekund na uruchomienie..."
sleep 5

# Sprawdź status
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "✅ Kontener uruchomiony pomyślnie!"
    echo ""
    
    # Sprawdź healthcheck
    echo "🔍 Sprawdzanie healthcheck..."
    sleep 5
    HEALTH=$(docker inspect "$CONTAINER" --format '{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck")
    if [ "$HEALTH" != "no-healthcheck" ]; then
        echo "   Status healthcheck: $HEALTH"
    fi
    
    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo "✅ MIGRACJA ZAKOŃCZONA POMYŚLNIE!"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    echo "📋 Sprawdź status:"
    echo "   docker compose ps"
    echo ""
    echo "📋 Sprawdź logi:"
    echo "   docker compose logs -f postgres-test"
    echo ""
    echo "📋 Test połączenia:"
    echo "   docker exec $CONTAINER psql -U testuser -d testdb -c 'SELECT version();'"
    echo ""
else
    echo "❌ BŁĄD: Kontener nie został uruchomiony!"
    echo ""
    echo "Sprawdź logi:"
    echo "   docker compose logs postgres-test"
    exit 1
fi




