# Konfiguracja testowego kontenera PostgreSQL

## Opis

Ten katalog zawiera konfigurację dla kontenera testowego PostgreSQL (`nc-postgres-test`), która rozwiązuje problem lagu w pierwszym połączeniu po okresie bezczynności.

## Różnice w stosunku do produkcyjnej konfiguracji

### Dodane optymalizacje:

1. **Healthcheck** - Kontener sprawdza gotowość przed akceptacją połączeń
2. **TCP Keepalive** - Zapobiega zamykaniu połączeń po idle (60s idle, 10s interval, 5 retries)
3. **Custom postgresql.conf** - Plik z optymalizacjami dla testowego środowiska
4. **Limity logowania** - `max-file: 3, max-size: 50m` - zapobiega przepełnieniu dysku
5. **Limity zasobów** - CPU i Memory limits dla stabilności
6. **PostgreSQL 18.1** - Najnowsza wersja z poprawkami wydajności

## Użycie

### Pierwsze uruchomienie:

```bash
cd ~/vps/stacks/test-postgres

# Skopiuj przykład pliku .env (opcjonalnie)
cp .env.example .env
# Edytuj .env i ustaw hasła

# Uruchom kontener
docker compose up -d
```

### Sprawdzenie statusu:

```bash
# Sprawdź status kontenera
docker compose ps

# Sprawdź logi
docker compose logs -f postgres-test

# Sprawdź healthcheck
docker inspect nc-postgres-test | grep -A 10 Health
```

### Zatrzymanie:

```bash
docker compose down
```

### Zatrzymanie z usunięciem volume (UWAGA: usuwa dane!):

```bash
docker compose down -v
```

## Port

Kontener testowy używa portu **5433** na hoście (produkcja używa 5432).

## Volume

Dane są przechowywane w Docker volume `nc_postgres_test_data`.

Aby sprawdzić lokalizację volume:
```bash
docker volume inspect nc_postgres_test_data
```

## Konfiguracja

### postgresql.conf

Plik `postgresql.conf` zawiera optymalizacje:
- TCP Keepalive settings (rozwiązuje problem lagu)
- Memory settings dostosowane do testowego środowiska
- SSD optimizations
- Connection settings

### docker-compose.yml

Zawiera:
- Healthcheck z `pg_isready`
- Limity logowania
- Limity zasobów (CPU/Memory)
- Mapowanie portu 5433:5432
- Custom network `test_network`

## Testy po wdrożeniu

### Test 1: Sprawdź healthcheck

```bash
docker inspect nc-postgres-test | grep -A 10 Health
```

### Test 2: Sprawdź TCP Keepalive

```bash
docker exec nc-postgres-test psql -U testuser -d testdb -c "SHOW tcp_keepalives_idle;"
# Powinno pokazać: 60
```

### Test 3: Zmierz czas pierwszego połączenia

```bash
# Poczekaj 2 minuty bez aktywności
sleep 120

# Zmierz czas połączenia
time docker exec nc-postgres-test psql -U testuser -d testdb -c "SELECT 1;"
```

**Oczekiwane wyniki:**
- ❌ PRZED: 5000-10000ms (5-10 sekund)
- ✅ PO: 50-200ms (< 200ms)

### Test 4: Sprawdź limity logowania

```bash
docker inspect nc-postgres-test | grep -A 5 LogConfig
```

## Migracja istniejącego kontenera

Jeśli masz już istniejący kontener `nc-postgres-test`, użyj skryptu migracyjnego:

```bash
~/vps/scripts/migrate-test-postgres.sh
```

## Backup

Volume `nc_postgres_test_data` zawiera dane bazy. Aby zrobić backup:

```bash
docker exec nc-postgres-test pg_dump -U testuser testdb > backup_$(date +%Y%m%d_%H%M%S).sql
```




