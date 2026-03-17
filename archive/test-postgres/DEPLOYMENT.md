# Przewodnik wdrożenia - Testowy PostgreSQL

## Szybki start

### 1. Przygotowanie

```bash
cd ~/vps/stacks/test-postgres
```

### 2. Konfiguracja hasła (opcjonalnie)

Edytuj `docker-compose.yml` i zmień hasło w sekcji `environment`:

```yaml
POSTGRES_PASSWORD: twoje_haslo
```

Lub utwórz plik `.env`:

```bash
cat > .env <<EOF
POSTGRES_USER=testuser
POSTGRES_PASSWORD=twoje_haslo
POSTGRES_DB=testdb
EOF
```

### 3. Uruchomienie

```bash
docker compose up -d
```

### 4. Weryfikacja

```bash
# Sprawdź status
docker compose ps

# Sprawdź logi
docker compose logs -f postgres-test

# Sprawdź połączenie
docker exec nc-postgres-test psql -U testuser -d testdb -c "SELECT version();"
```

## Migracja istniejącego kontenera

Jeśli masz już działający kontener `nc-postgres-test`:

### Krok 1: Zatrzymaj i zrób backup

```bash
# Zatrzymaj kontener
docker stop nc-postgres-test

# Zrób backup danych (jeśli potrzebujesz)
docker run --rm -v nc_postgres_test_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_backup.tar.gz /data
```

### Krok 2: Użyj skryptu migracyjnego

```bash
~/vps/scripts/migrate-test-postgres.sh
```

### Krok 3: Uruchom nowy kontener

```bash
cd ~/vps/stacks/test-postgres
docker compose up -d
```

## Szybka poprawka (bez migracji)

Jeśli chcesz tylko dodać TCP keepalive do istniejącego kontenera:

```bash
~/vps/scripts/fix-test-postgres-quick.sh
```

## Testy wydajności

### Przed optymalizacją

```bash
# 1. Zatrzymaj aktywność na 2 minuty
sleep 120

# 2. Zmierz czas pierwszego połączenia
time docker exec nc-postgres-test psql -U testuser -d testdb -c "SELECT 1;"
```

Oczekiwany wynik: **5000-10000ms** (5-10 sekund) ❌

### Po optymalizacji

```bash
# 1. Zatrzymaj aktywność na 2 minuty
sleep 120

# 2. Zmierz czas pierwszego połączenia
time docker exec nc-postgres-test psql -U testuser -d testdb -c "SELECT 1;"
```

Oczekiwany wynik: **50-200ms** (< 200ms) ✅

### Sprawdzenie ustawień

```bash
# Sprawdź TCP keepalive
docker exec nc-postgres-test psql -U testuser -d testdb -c "SHOW tcp_keepalives_idle;"

# Sprawdź healthcheck
docker inspect nc-postgres-test | grep -A 10 Health

# Sprawdź limity logowania
docker inspect nc-postgres-test | grep -A 5 LogConfig
```

## Rozwiązywanie problemów

### Kontener nie startuje

```bash
# Sprawdź logi
docker compose logs postgres-test

# Sprawdź czy port 5433 jest wolny
netstat -tuln | grep 5433
```

### Błąd przy montowaniu postgresql.conf

```bash
# Sprawdź czy plik istnieje
ls -la ~/vps/stacks/test-postgres/postgresql.conf

# Sprawdź uprawnienia
chmod 644 ~/vps/stacks/test-postgres/postgresql.conf
```

### Problem z połączeniem

```bash
# Sprawdź czy kontener działa
docker ps | grep nc-postgres-test

# Sprawdź healthcheck
docker inspect nc-postgres-test | grep -A 10 Health

# Sprawdź port
docker port nc-postgres-test
```

## Dostosowanie konfiguracji

### Zmiana limitu pamięci

Edytuj `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      memory: 4G  # Zmień z 2G na 4G
```

### Zmiana ustawień PostgreSQL

Edytuj `postgresql.conf` i zrestartuj kontener:

```bash
docker compose restart postgres-test
```

### Zmiana portu

Edytuj `docker-compose.yml`:

```yaml
ports:
  - "5434:5432"  # Zmień z 5433 na 5434
```

## Backup i restore

### Backup

```bash
docker exec nc-postgres-test pg_dump -U testuser testdb > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Restore

```bash
cat backup_*.sql | docker exec -i nc-postgres-test psql -U testuser -d testdb
```

## Zatrzymanie i usunięcie

### Zatrzymanie

```bash
docker compose down
```

### Zatrzymanie z usunięciem volume (UWAGA: usuwa dane!)

```bash
docker compose down -v
```

## Przydatne komendy

```bash
# Status kontenera
docker compose ps

# Logi w czasie rzeczywistym
docker compose logs -f postgres-test

# Shell w kontenerze
docker exec -it nc-postgres-test /bin/sh

# Połączenie do bazy
docker exec -it nc-postgres-test psql -U testuser -d testdb

# Restart kontenera
docker compose restart postgres-test

# Statystyki zasobów
docker stats nc-postgres-test
```

## Wsparcie

- Pełna dokumentacja: `~/vps/docs/POSTGRES_TEST_OPTIMIZATION.md`
- README: `~/vps/stacks/test-postgres/README.md`
- Skrypty: `~/vps/scripts/`




