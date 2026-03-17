#!/bin/bash
# Skrypt do migracji istniejącego kontenera testowego PostgreSQL
# Przeznaczony do uruchomienia na serwerze, gdzie kontener faktycznie działa

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   MIGRACJA KONTENERA nc-postgres-test (OPCJA 2)            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

CONTAINER="nc-postgres-test"
COMPOSE_DIR="$HOME/vps/stacks/test-postgres"

# Sprawdź czy kontener istnieje
if ! docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
    echo "❌ BŁĄD: Kontener '$CONTAINER' nie został znaleziony."
    echo ""
    echo "Upewnij się, że:"
    echo "  1. Jesteś połączony z właściwym serwerem"
    echo "  2. Kontener rzeczywiście istnieje (sprawdź: docker ps -a)"
    echo ""
    exit 1
fi

echo "✅ Znaleziono kontener: $CONTAINER"
echo ""

# Pokaż informacje o kontenerze
echo "📊 Informacje o kontenerze:"
echo "────────────────────────────────────────────────────────────────"
docker inspect "$CONTAINER" --format '   Nazwa: {{.Name}}
   Status: {{.State.Status}}
   Obraz: {{.Config.Image}}
   Utworzony: {{.Created}}' 2>/dev/null || true
echo ""

# Sprawdź czy kontener działa
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
    echo "⚠️  Kontener jest uruchomiony. Zatrzymywanie..."
    docker stop "$CONTAINER" || {
        echo "❌ Nie udało się zatrzymać kontenera!"
        exit 1
    }
    echo "✅ Kontener został zatrzymany."
else
    echo "ℹ️  Kontener jest już zatrzymany."
fi
echo ""

# Sprawdź volume
echo "🔍 Sprawdzanie volume z danymi..."
VOLUME_NAME=$(docker inspect "$CONTAINER" --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{end}}{{end}}' 2>/dev/null | head -1)

if [ -n "$VOLUME_NAME" ]; then
    echo "✅ Znaleziono volume: $VOLUME_NAME"
    echo "   Dane będą zachowane podczas migracji!"
else
    echo "⚠️  Nie znaleziono volume. Sprawdzam bind mounty..."
    BIND_MOUNT=$(docker inspect "$CONTAINER" --format '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}{{end}}{{end}}' 2>/dev/null | head -1)
    if [ -n "$BIND_MOUNT" ]; then
        echo "✅ Znaleziono bind mount: $BIND_MOUNT"
        echo "   UWAGA: Musisz zaktualizować docker-compose.yml z tym ścieżką!"
    else
        echo "⚠️  Nie znaleziono volume ani bind mount. Sprawdzanie..."
    fi
fi
echo ""

# Sprawdź czy istnieją pliki konfiguracyjne
if [ ! -f "$COMPOSE_DIR/docker-compose.yml" ]; then
    echo "❌ BŁĄD: Nie znaleziono pliku docker-compose.yml w $COMPOSE_DIR"
    echo ""
    echo "Upewnij się, że pliki konfiguracyjne zostały skopiowane na serwer."
    exit 1
fi

if [ ! -f "$COMPOSE_DIR/postgresql.conf" ]; then
    echo "❌ BŁĄD: Nie znaleziono pliku postgresql.conf w $COMPOSE_DIR"
    echo ""
    echo "Upewnij się, że pliki konfiguracyjne zostały skopiowane na serwer."
    exit 1
fi

echo "✅ Pliki konfiguracyjne są dostępne."
echo ""

# Pobierz użytkownika i hasło z istniejącego kontenera (jeśli możliwe)
echo "🔐 Próba odczytania konfiguracji z istniejącego kontenera..."
DB_USER=$(docker inspect "$CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -E '^POSTGRES_USER=' | cut -d'=' -f2 || echo "")
DB_PASSWORD=$(docker inspect "$CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -E '^POSTGRES_PASSWORD=' | cut -d'=' -f2 || echo "")

if [ -n "$DB_USER" ]; then
    echo "   Użytkownik: $DB_USER"
fi
if [ -z "$DB_PASSWORD" ]; then
    echo "   ⚠️  Nie udało się odczytać hasła. Musisz je ustawić ręcznie w docker-compose.yml"
fi
echo ""

echo "────────────────────────────────────────────────────────────────"
echo "📋 PLAN MIGRACJI:"
echo "────────────────────────────────────────────────────────────────"
echo ""
echo "1. ✅ Kontener został zatrzymany"
echo "2. ⏭️  Stary kontener zostanie usunięty (po Twojej zgodzie)"
echo "3. ⏭️  Nowy kontener zostanie utworzony z docker-compose"
echo "4. ✅ Volume z danymi zostanie zachowany"
echo "5. ✅ Wszystkie optymalizacje zostaną zastosowane"
echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""

read -p "Czy chcesz usunąć stary kontener i kontynuować migrację? (y/N): " -n 1 -r
echo
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Migracja anulowana. Kontener pozostaje zatrzymany."
    echo ""
    echo "Możesz go uruchomić ponownie:"
    echo "  docker start $CONTAINER"
    exit 0
fi

echo "🗑️  Usuwanie starego kontenera..."
docker rm "$CONTAINER" || {
    echo "❌ Nie udało się usunąć kontenera. Może być używany przez inny proces."
    exit 1
}
echo "✅ Stary kontener został usunięty."
echo ""

echo "────────────────────────────────────────────────────────────────"
echo "📝 NASTĘPNE KROKI:"
echo "────────────────────────────────────────────────────────────────"
echo ""
echo "1. Przejdź do katalogu z konfiguracją:"
echo "   cd $COMPOSE_DIR"
echo ""
echo "2. Sprawdź i ustaw hasło w docker-compose.yml (linia 9)"
if [ -n "$DB_USER" ]; then
    echo "   Obecny użytkownik w kontenerze: $DB_USER"
fi
echo ""
echo "3. Jeśli kontener używał innego volume, zaktualizuj docker-compose.yml"
if [ -n "$VOLUME_NAME" ] && [ "$VOLUME_NAME" != "nc_postgres_test_data" ]; then
    echo "   ⚠️  Uwaga: Kontener używał volume: $VOLUME_NAME"
    echo "   Sprawdź czy docker-compose.yml używa właściwego volume!"
fi
echo ""
echo "4. Uruchom nowy kontener:"
echo "   docker compose up -d"
echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""

read -p "Czy chcesz teraz przejść do katalogu i sprawdzić konfigurację? (y/N): " -n 1 -r
echo
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Przechodzenie do katalogu..."
    cd "$COMPOSE_DIR" || exit 1
    echo ""
    echo "📄 Zawartość docker-compose.yml:"
    echo "────────────────────────────────────────────────────────────────"
    grep -A 5 "POSTGRES_PASSWORD" docker-compose.yml || echo "Nie znaleziono hasła w docker-compose.yml"
    echo ""
    echo "Możesz teraz:"
    echo "  1. Edytować hasło: nano docker-compose.yml (lub vim/vi)"
    echo "  2. Uruchomić kontener: docker compose up -d"
fi

echo ""
echo "✅ Przygotowanie migracji zakończone!"
echo ""




