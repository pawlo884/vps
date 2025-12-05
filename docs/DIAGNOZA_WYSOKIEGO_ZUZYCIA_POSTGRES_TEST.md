# Diagnoza wysokiego zużycia zasobów - nc-postgres-test

## Możliwe przyczyny wysokiego zużycia zasobów

### 1. **Monitoring (Netdata/Prometheus)**
- **Problem**: Netdata pobiera metryki co 10 sekund (`update_every: 10`)
- **Sprawdź**: Czy kontener testowy jest monitorowany przez Netdata
- **Diagnoza**:
  ```bash
  # Sprawdź konfigurację Netdata
  docker exec netdata cat /etc/netdata/go.d/postgres.conf
  
  # Sprawdź czy Netdata łączy się z kontenerem testowym
  docker logs netdata | grep -i "postgres.*test\|nc-postgres"
  ```

### 2. **Healthcheck zbyt częsty**
- **Problem**: Healthcheck co 10 sekund może generować ruch sieciowy
- **Aktualna konfiguracja**: `interval: 10s`
- **Diagnoza**: Sprawdź logi kontenera pod kątem healthcheck
- **Rozwiązanie**: Zwiększ interval do 30s jeśli nie jest krytyczny

### 3. **Aktywne połączenia i długie zapytania**
- **Problem**: Wiele aktywnych połączeń lub długie zapytania
- **Diagnoza**: Uruchom skrypt diagnostyczny:
  ```bash
  ~/vps/scripts/diagnose-postgres-test.sh
  ```
- **Sprawdź**:
  - Liczbę aktywnych połączeń
  - Długie zapytania (>5 sekund)
  - Połączenia w stanie `idle in transaction`

### 4. **Backupy lub replikacje**
- **Problem**: Automatyczne backupy lub replikacje mogą generować duży ruch
- **Diagnoza**:
  ```bash
  # Sprawdź czy są replikacje
  docker exec nc-postgres-test psql -U testuser -d testdb -c "SELECT * FROM pg_stat_replication;"
  
  # Sprawdź procesy backupowe
  docker exec nc-postgres-test ps aux | grep -E "pg_dump|pg_basebackup|backup"
  ```

### 5. **Aplikacje łączące się z bazą**
- **Problem**: Aplikacje mogą często łączyć się z bazą testową
- **Diagnoza**: Sprawdź aktywne połączenia i ich źródła:
  ```bash
  docker exec nc-postgres-test psql -U testuser -d testdb -c "
    SELECT 
        pid,
        usename,
        application_name,
        client_addr,
        state,
        query
    FROM pg_stat_activity 
    WHERE datname = 'testdb';
  "
  ```

### 6. **Autovacuum lub maintenance**
- **Problem**: Autovacuum może generować I/O
- **Diagnoza**:
  ```bash
  docker exec nc-postgres-test psql -U testuser -d testdb -c "
    SELECT 
        schemaname,
        tablename,
        last_vacuum,
        last_autovacuum,
        last_analyze,
        last_autoanalyze
    FROM pg_stat_user_tables
    ORDER BY last_autovacuum DESC;
  "
  ```

### 7. **Duże tabele bez indeksów**
- **Problem**: Zapytania na dużych tabelach bez indeksów
- **Diagnoza**: Sprawdź rozmiary tabel i statystyki zapytań:
  ```bash
  docker exec nc-postgres-test psql -U testuser -d testdb -c "
    SELECT 
        schemaname,
        tablename,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
        seq_scan,
        seq_tup_read,
        idx_scan,
        idx_tup_fetch
    FROM pg_stat_user_tables
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
    LIMIT 10;
  "
  ```

## Skrypt diagnostyczny

Uruchom pełną diagnostykę:
```bash
~/vps/scripts/diagnose-postgres-test.sh
```

Skrypt sprawdza:
1. Status kontenera
2. Statystyki zasobów (CPU, Memory, Network, I/O)
3. Aktywne połączenia
4. Długie zapytania
5. Statystyki połączeń
6. Rozmiary tabel
7. Procesy w kontenerze
8. Ostatnie logi
9. Replikacje i backupy
10. Konfigurację PostgreSQL
11. Aktywność I/O
12. Narzędzia monitorujące

## Najczęstsze przyczyny wysokiego ruchu sieciowego (21-22 MB RX/TX)

1. **Netdata monitoring** - jeśli kontener jest monitorowany, Netdata wykonuje wiele zapytań co 10 sekund
2. **Healthcheck** - co 10 sekund generuje mały ruch
3. **Aplikacje** - częste połączenia i zapytania z aplikacji
4. **Backupy** - jeśli są automatyczne backupy
5. **Replikacje** - jeśli jest skonfigurowana replikacja

## Szybka diagnoza

```bash
# 1. Sprawdź aktywne połączenia
docker exec nc-postgres-test psql -U testuser -d testdb -c "
  SELECT count(*) as total, 
         count(*) FILTER (WHERE state = 'active') as active,
         count(*) FILTER (WHERE state = 'idle') as idle
  FROM pg_stat_activity WHERE datname = 'testdb';
"

# 2. Sprawdź źródła połączeń
docker exec nc-postgres-test psql -U testuser -d testdb -c "
  SELECT client_addr, application_name, count(*) 
  FROM pg_stat_activity 
  WHERE datname = 'testdb' 
  GROUP BY client_addr, application_name;
"

# 3. Sprawdź czy Netdata monitoruje
docker exec netdata cat /etc/netdata/go.d/postgres.conf 2>/dev/null | grep -i test || echo "Kontener testowy nie jest monitorowany przez Netdata"

# 4. Sprawdź statystyki sieciowe
docker stats nc-postgres-test --no-stream --format "{{.NetIO}}"
```

## Następne kroki

Po zidentyfikowaniu przyczyny:
1. Jeśli to monitoring - rozważ zwiększenie `update_every` lub wyłączenie monitoringu dla testowego kontenera
2. Jeśli to aplikacje - zoptymalizuj zapytania lub użyj connection pooling
3. Jeśli to backupy - sprawdź harmonogram i optymalizuj
4. Jeśli to healthcheck - zwiększ interval jeśli nie jest krytyczny



