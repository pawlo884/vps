# Optymalizacja kontenera testowego PostgreSQL

## Problem

Kontener testowy PostgreSQL (`nc-postgres-test`) doświadcza znaczącego lagu (5-10 sekund) przy pierwszym połączeniu po okresie bezczynności.

## Analiza różnic: Test vs Produkcja

### 🔴 Krytyczne różnice powodujące lag:

1. **Brak Healthcheck** (TEST ❌ vs PROD ✅)
   - TEST: Brak healthcheck - kontener może nie być w pełni gotowy
   - PROD: Healthcheck z `pg_isready` co 10s
   - Wpływ: Aplikacja może próbować łączyć się z bazą zanim jest gotowa

2. **Brak optymalizacji PostgreSQL** (TEST ❌ vs PROD ✅)
   - TEST: Brak custom `postgresql.conf`
   - PROD: Używa optymalizacji z TCP Keepalive
   - Wpływ: Wolne pierwsze połączenia po idle, brak cache'owania

3. **Brak limitów logowania** (TEST ❌ vs PROD ✅)
   - TEST: Domyślne logowanie bez limitów
   - PROD: `max-file: 3, max-size: 50m`
   - Wpływ: Logi mogą rosnąć i spowalniać I/O

4. **Różne typy storage** (TEST vs PROD)
   - TEST: Docker volume `nc_postgres_test_data`
   - PROD: Bind mount `/mnt/data2tb/docker/volumes/nc_postgres_data`
   - Wpływ: Docker volumes mogą być wolniejsze niż bind mounts na SSD

5. **Różne wersje PostgreSQL** (TEST vs PROD)
   - TEST: `PG_VERSION=18.0`
   - PROD: `PG_VERSION=18.1`
   - Wpływ: Możliwe poprawki wydajności w nowszej wersji

## Rozwiązanie

Stworzono kompletną konfigurację w `/home/pawlo/vps/stacks/test-postgres/`:

### Pliki:

1. **docker-compose.yml** - Kompletna konfiguracja kontenera z:
   - Healthcheck
   - TCP Keepalive settings
   - Limity logowania
   - Limity zasobów (CPU/Memory)
   - Custom network

2. **postgresql.conf** - Plik konfiguracyjny z optymalizacjami:
   - TCP Keepalive (60s idle, 10s interval, 5 retries)
   - Memory settings dostosowane do testowego środowiska
   - SSD optimizations
   - Connection settings

3. **README.md** - Dokumentacja użycia i testów

## Wdrożenie

### Opcja 1: Migracja istniejącego kontenera

```bash
# Użyj skryptu migracyjnego
~/vps/scripts/migrate-test-postgres.sh

# Następnie uruchom nowy kontener
cd ~/vps/stacks/test-postgres
docker compose up -d
```

### Opcja 2: Szybka poprawka (bez migracji)

```bash
# Dodaje tylko TCP keepalive do istniejącego kontenera
~/vps/scripts/fix-test-postgres-quick.sh
```

### Opcja 3: Nowy kontener od zera

```bash
cd ~/vps/stacks/test-postgres
docker compose up -d
```

## Priorytety naprawy

### 🔴 WYSOKIE (natychmiastowe):

1. ✅ **Dodaj healthcheck** - zapobiega połączeniom przed gotowością
2. ✅ **Dodaj postgresql.conf** - rozwiązuje problem wolnych pierwszych połączeń
3. ✅ **Dodaj limity logowania** - zapobiega przepełnieniu dysku

### 🟡 ŚREDNIE (w najbliższym czasie):

4. ⚠️ **Zaktualizuj do PostgreSQL 18.1** - możliwe poprawki wydajności
5. ⚠️ **Dodaj limity zasobów** - zapobiega konkurowaniu z innymi kontenerami

### 🟢 NISKIE (opcjonalne):

6. ℹ️ **Rozważ bind mount zamiast volume** - jeśli masz szybki SSD

## Testy po naprawie

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

## Notatki

- Kontener testowy używa portu **5433** (produkcja używa 5432)
- Volume `nc_postgres_test_data` jest używany do przechowywania danych
- Wszystkie zmiany są backward compatible
- Plik `postgresql.conf` jest montowany jako read-only

## Zastosowane optymalizacje

### TCP Keepalive
- `tcp_keepalives_idle = 60` - Czas idle przed rozpoczęciem keepalive (60 sekund)
- `tcp_keepalives_interval = 10` - Interwał między próbami keepalive (10 sekund)
- `tcp_keepalives_count = 5` - Liczba prób przed zamknięciem połączenia (5)

### Memory Settings
- `shared_buffers = 256MB` - Dla testowego środowiska
- `effective_cache_size = 1GB` - Szacowany rozmiar cache
- `work_mem = 4MB` - Pamięć dla operacji sortowania
- `maintenance_work_mem = 64MB` - Pamięć dla operacji maintenance

### SSD Optimizations
- `random_page_cost = 1.1` - Optymalizacja dla SSD
- `effective_io_concurrency = 200` - Równoległe operacje I/O

## Struktura katalogów

```
~/vps/stacks/test-postgres/
├── docker-compose.yml      # Konfiguracja kontenera
├── postgresql.conf         # Optymalizacje PostgreSQL
└── README.md               # Dokumentacja użycia
```

## Skrypty pomocnicze

```
~/vps/scripts/
├── migrate-test-postgres.sh    # Migracja istniejącego kontenera
└── fix-test-postgres-quick.sh  # Szybka poprawka TCP keepalive
```

## Referencje

- Analiza lagu w kontenerze testowym PostgreSQL (dokumentacja użytkownika)
- PostgreSQL TCP Keepalive documentation
- Docker healthcheck documentation




