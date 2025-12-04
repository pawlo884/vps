#!/bin/bash
# Skrypt do migracji istniejącego kontenera testowego PostgreSQL
# do nowej konfiguracji z docker-compose i optymalizacjami

set -e

echo "=== Migracja kontenera nc-postgres-test ==="
echo ""

CONTAINER="nc-postgres-test"
COMPOSE_DIR="$HOME/vps/stacks/test-postgres"

# Sprawdź czy kontener istnieje
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "Kontener $CONTAINER nie istnieje."
    echo "Możesz uruchomić nowy kontener używając docker-compose:"
    echo "  cd $COMPOSE_DIR && docker compose up -d"
    exit 0
fi

echo "Znaleziono kontener: $CONTAINER"

# Sprawdź czy kontener działa
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "Kontener działa. Zatrzymywanie..."
    docker stop "$CONTAINER"
else
    echo "Kontener jest zatrzymany."
fi

# Sprawdź czy istnieje docker-compose.yml
if [ ! -f "$COMPOSE_DIR/docker-compose.yml" ]; then
    echo "BŁĄD: Nie znaleziono pliku docker-compose.yml w $COMPOSE_DIR"
    echo "Upewnij się, że plik istnieje przed migracją."
    exit 1
fi

# Sprawdź czy istnieje postgresql.conf
if [ ! -f "$COMPOSE_DIR/postgresql.conf" ]; then
    echo "BŁĄD: Nie znaleziono pliku postgresql.conf w $COMPOSE_DIR"
    echo "Upewnij się, że plik istnieje przed migracją."
    exit 1
fi

echo ""
echo "Kontener został zatrzymany."
echo ""
echo "Następne kroki:"
echo "1. Sprawdź konfigurację w $COMPOSE_DIR/docker-compose.yml"
echo "2. Ustaw odpowiednie hasła (w .env lub bezpośrednio w docker-compose.yml)"
echo "3. Uruchom nowy kontener:"
echo "   cd $COMPOSE_DIR"
echo "   docker compose up -d"
echo ""
echo "UWAGA:"
echo "- Volume nc_postgres_test_data zostanie użyty automatycznie"
echo "- Dane z istniejącego kontenera zostaną zachowane"
echo "- Stary kontener zostanie zastąpiony nowym z docker-compose"
echo ""
read -p "Czy chcesz usunąć stary kontener? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Usuwanie starego kontenera..."
    docker rm "$CONTAINER"
    echo "Stary kontener został usunięty."
else
    echo "Stary kontener pozostaje. Możesz go usunąć ręcznie:"
    echo "  docker rm $CONTAINER"
fi

echo ""
echo "=== Zakończono przygotowanie migracji ==="
echo "Teraz możesz uruchomić nowy kontener używając docker-compose."

