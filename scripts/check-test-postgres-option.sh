#!/bin/bash
# Skrypt pomagający wybrać odpowiednią opcję wdrożenia

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   Sprawdzanie: Którą opcję wdrożenia wybrać?               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

CONTAINER="nc-postgres-test"
VOLUME="nc_postgres_test_data"

# Sprawdź czy kontener istnieje
CONTAINER_EXISTS=0
if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
    CONTAINER_EXISTS=1
fi

CONTAINER_RUNNING=0
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
    CONTAINER_RUNNING=1
fi

# Sprawdź czy volume istnieje
VOLUME_EXISTS=0
if docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q "^${VOLUME}$"; then
    VOLUME_EXISTS=1
fi

echo "📊 Status obecny:"
echo "────────────────────────────────────────────────────────────────"
echo ""

if [ "$CONTAINER_EXISTS" -eq "1" ]; then
    if [ "$CONTAINER_RUNNING" -eq "1" ]; then
        echo "✅ Kontener '$CONTAINER' istnieje i DZIAŁA"
    else
        echo "⚠️  Kontener '$CONTAINER' istnieje, ale jest ZATRZYMANY"
    fi
else
    echo "❌ Kontener '$CONTAINER' NIE ISTNIEJE"
fi

if [ "$VOLUME_EXISTS" -eq "1" ]; then
    echo "✅ Volume '$VOLUME' istnieje"
    
    # Sprawdź rozmiar volume
    VOLUME_SIZE=$(docker system df -v 2>/dev/null | grep "$VOLUME" | awk '{print $3}' || echo "nieznany")
    if [ -n "$VOLUME_SIZE" ] && [ "$VOLUME_SIZE" != "nieznany" ]; then
        echo "   Rozmiar volume: $VOLUME_SIZE"
    fi
else
    echo "❌ Volume '$VOLUME' NIE ISTNIEJE"
fi

echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""
echo "🎯 REKOMENDACJA:"
echo "────────────────────────────────────────────────────────────────"
echo ""

if [ "$CONTAINER_EXISTS" -eq "1" ]; then
    echo "📌 Użyj OPCJI 2: MIGRACJA ISTNIEJĄCEGO KONTENERA"
    echo ""
    echo "   Powód: Masz już kontener, który może zawierać dane"
    echo ""
    echo "   Komendy:"
    echo "   1. ~/vps/scripts/migrate-test-postgres.sh"
    echo "   2. cd ~/vps/stacks/test-postgres"
    echo "   3. docker compose up -d"
    echo ""
    
    if [ "$VOLUME_EXISTS" -eq "1" ]; then
        echo "   ⚠️  UWAGA: Volume z danymi istnieje - dane będą zachowane!"
        echo ""
        read -p "   Czy chcesz zobaczyć zawartość volume? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo "   Sprawdzanie zawartości volume..."
            docker run --rm -v "$VOLUME":/data alpine ls -lah /data/ 2>/dev/null | head -10 || echo "   Nie można odczytać zawartości volume"
        fi
    fi
else
    echo "📌 Użyj OPCJI 1: NOWY KONTENER"
    echo ""
    echo "   Powód: Nie masz jeszcze kontenera testowego"
    echo ""
    echo "   Komendy:"
    echo "   1. cd ~/vps/stacks/test-postgres"
    echo "   2. Edytuj hasło w docker-compose.yml (linia 9)"
    echo "   3. docker compose up -d"
    echo ""
    
    if [ "$VOLUME_EXISTS" -eq "1" ]; then
        echo "   ⚠️  UWAGA: Volume '$VOLUME' istnieje, ale kontener nie."
        echo "   Jeśli volume zawiera dane, rozważ Opcję 2."
        echo ""
    fi
fi

echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""
echo "📚 Więcej informacji:"
echo "   ~/vps/stacks/test-postgres/OPCJE_WDROZENIA.md"
echo ""

