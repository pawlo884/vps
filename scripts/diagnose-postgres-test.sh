#!/bin/bash
# Skrypt diagnostyczny dla kontenera nc-postgres-test
# Sprawdza przyczyny wysokiego zużycia zasobów

CONTAINER_NAME="nc-postgres-test"
CONTAINER_ID="1b9a9e973832093b37790cfad13557a3c2fdb8ad8a34ba375a54b14d219243de"

echo "=========================================="
echo "Diagnostyka kontenera: $CONTAINER_NAME"
echo "=========================================="
echo ""

# Sprawdź czy kontener istnieje (najpierw po nazwie, potem po ID)
CONTAINER_TO_USE=""
if docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    CONTAINER_TO_USE="$CONTAINER_NAME"
elif docker ps -a --format "{{.ID}}" | grep -q "^${CONTAINER_ID}$"; then
    CONTAINER_TO_USE="$CONTAINER_ID"
else
    echo "UWAGA: Kontener nie znaleziony lokalnie!"
    echo "Kontener może być na zdalnym hoście Docker."
    echo "Użyj: DOCKER_HOST=... $0"
    echo ""
    CONTAINER_TO_USE="$CONTAINER_NAME"  # Spróbuj użyć nazwy mimo wszystko
fi

# 1. Sprawdź status kontenera
echo "1. STATUS KONTENERA:"
echo "-------------------"
docker ps --filter "name=$CONTAINER_NAME" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
docker ps --filter "id=$CONTAINER_ID" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
echo "Kontener nie znaleziony lokalnie"
echo ""

# 2. Statystyki zasobów
echo "2. STATYSTYKI ZASOBÓW:"
echo "---------------------"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" $CONTAINER_TO_USE 2>/dev/null || \
echo "Nie można pobrać statystyk (kontener może być na zdalnym hoście)"
echo ""

# 3. Aktywne połączenia do bazy
echo "3. AKTYWNE POŁĄCZENIA DO BAZY:"
echo "------------------------------"
docker exec $CONTAINER_TO_USE psql -U testuser -d testdb -c "
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query_start,
    state_change,
    wait_event_type,
    wait_event,
    query
FROM pg_stat_activity 
WHERE datname = 'testdb'
ORDER BY query_start;
" 2>/dev/null || echo "Nie można sprawdzić połączeń"
echo ""

# 4. Długie zapytania
echo "4. DŁUGIE ZAPYTANIA (>5 sekund):"
echo "--------------------------------"
docker exec $CONTAINER_TO_USE psql -U testuser -d testdb -c "
SELECT 
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query,
    state
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 seconds'
  AND state != 'idle'
ORDER BY duration DESC;
" 2>/dev/null || echo "Nie można sprawdzić długich zapytań"
echo ""

# 5. Statystyki połączeń
echo "5. STATYSTYKI POŁĄCZEŃ:"
echo "----------------------"
docker exec $CONTAINER_TO_USE psql -U testuser -d testdb -c "
SELECT 
    count(*) as total_connections,
    count(*) FILTER (WHERE state = 'active') as active,
    count(*) FILTER (WHERE state = 'idle') as idle,
    count(*) FILTER (WHERE state = 'idle in transaction') as idle_in_transaction,
    count(*) FILTER (WHERE wait_event_type IS NOT NULL) as waiting
FROM pg_stat_activity
WHERE datname = 'testdb';
" 2>/dev/null || echo "Nie można sprawdzić statystyk"
echo ""

# 6. Największe tabele i ich rozmiary
echo "6. ROZMIARY TABEL:"
echo "-----------------"
docker exec $CONTAINER_TO_USE psql -U testuser -d testdb -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS indexes_size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
" 2>/dev/null || echo "Nie można sprawdzić rozmiarów tabel"
echo ""

# 7. Procesy w kontenerze
echo "7. PROCESY W KONTENERZE:"
echo "-----------------------"
docker exec $CONTAINER_TO_USE ps aux 2>/dev/null || echo "Nie można sprawdzić procesów"
echo ""

# 8. Ostatnie logi (ostatnie 50 linii)
echo "8. OSTATNIE LOGI (ostatnie 50 linii):"
echo "-------------------------------------"
docker logs --tail 50 $CONTAINER_TO_USE 2>/dev/null || echo "Nie można pobrać logów"
echo ""

# 9. Sprawdź czy są replikacje lub backupi
echo "9. REPLIKACJE I BACKUPY:"
echo "------------------------"
docker exec $CONTAINER_TO_USE psql -U testuser -d testdb -c "
SELECT 
    application_name,
    client_addr,
    state,
    sync_state,
    sync_priority
FROM pg_stat_replication;
" 2>/dev/null || echo "Brak replikacji lub nie można sprawdzić"
echo ""

# 10. Sprawdź konfigurację PostgreSQL
echo "10. KONFIGURACJA POSTGRESQL (ważne parametry):"
echo "----------------------------------------------"
docker exec $CONTAINER_TO_USE psql -U testuser -d testdb -c "
SELECT name, setting, unit, source
FROM pg_settings
WHERE name IN (
    'max_connections',
    'shared_buffers',
    'effective_cache_size',
    'work_mem',
    'maintenance_work_mem',
    'max_wal_size',
    'checkpoint_timeout',
    'tcp_keepalives_idle',
    'tcp_keepalives_interval',
    'tcp_keepalives_count'
)
ORDER BY name;
" 2>/dev/null || echo "Nie można sprawdzić konfiguracji"
echo ""

# 11. Sprawdź aktywność I/O
echo "11. AKTYWNOŚĆ I/O:"
echo "-----------------"
docker exec $CONTAINER_TO_USE psql -U testuser -d testdb -c "
SELECT 
    datname,
    blks_read,
    blks_hit,
    round(100.0 * blks_hit / (blks_hit + blks_read), 2) AS cache_hit_ratio
FROM pg_stat_database
WHERE datname = 'testdb';
" 2>/dev/null || echo "Nie można sprawdzić I/O"
echo ""

# 12. Sprawdź czy Netdata lub inne narzędzia monitorują ten kontener
echo "12. SPRAWDŹ MONITORING:"
echo "----------------------"
echo "Sprawdź czy Netdata lub inne narzędzia monitorują ten kontener:"
docker ps --format "{{.Names}}" | grep -E "(netdata|monitoring|prometheus)" || echo "Brak kontenerów monitorujących"
echo ""

echo "=========================================="
echo "Diagnostyka zakończona"
echo "=========================================="

