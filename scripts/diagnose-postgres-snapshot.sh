#!/bin/bash
# Skrypt diagnostyczny - sprawdza źródło starego snapshotu bazy danych
# Użycie: ssh user@vps 'bash -s' < scripts/diagnose-postgres-snapshot.sh

set -e

echo "=========================================="
echo "DIAGNOZA: ŹRÓDŁO STAREGO SNAPSHOTU BAZY"
echo "=========================================="
echo ""

echo "=== 1. SPRAWDZENIE MONTOWANIA DYSKU I BINDÓW ==="
echo ""
echo "--- 1.1. /etc/fstab (data2tb, docker, postgres) ---"
sudo cat /etc/fstab | grep -E 'data2tb|docker|postgres' || echo "BRAK wpisów data2tb/docker/postgres w fstab"
echo ""

echo "--- 1.2. Aktualne mounty (data2tb, docker, postgres) ---"
mount | grep -E 'data2tb|docker|postgres' || echo "BRAK mountów data2tb/docker/postgres"
echo ""

echo "--- 1.3. Struktura /mnt/data2tb ---"
ls -l /mnt/data2tb 2>/dev/null | head -20 || echo "Katalog /mnt/data2tb nie istnieje"
echo ""

echo "--- 1.4. Struktura /mnt/data2tb/docker ---"
ls -l /mnt/data2tb/docker 2>/dev/null | head -20 || echo "Katalog /mnt/data2tb/docker nie istnieje"
echo ""

echo "--- 1.5. Struktura /mnt/data2tb/docker/volumes ---"
ls -l /mnt/data2tb/docker/volumes 2>/dev/null | head -20 || echo "Katalog /mnt/data2tb/docker/volumes nie istnieje"
echo ""

echo "--- 1.6. Zawartość /mnt/data2tb/docker/volumes/nc_postgres_data ---"
if [ -d "/mnt/data2tb/docker/volumes/nc_postgres_data" ]; then
    echo "Katalog istnieje:"
    ls -lth /mnt/data2tb/docker/volumes/nc_postgres_data | head -20
    echo ""
    echo "Rozmiar:"
    du -sh /mnt/data2tb/docker/volumes/nc_postgres_data
    echo ""
    echo "Najnowsze pliki (ostatnie 10):"
    find /mnt/data2tb/docker/volumes/nc_postgres_data -type f -printf '%T@ %TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort -rn | head -10 | awk '{print $2" "$3" "$4}'
else
    echo "Katalog /mnt/data2tb/docker/volumes/nc_postgres_data NIE ISTNIEJE"
fi
echo ""

echo "=== 2. STARE VS NOWE KONTENERY POSTGRES ==="
echo ""
echo "--- 2.1. Wszystkie kontenery postgres (w tym zatrzymane) ---"
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.CreatedAt}}' | grep -i postgres || echo "BRAK kontenerów postgres"
echo ""

echo "--- 2.2. Mounts obecnego kontenera nc-postgres-1 ---"
docker inspect nc-postgres-1 --format '{{json .Mounts}}' 2>/dev/null | python3 -m json.tool || echo "Kontener nc-postgres-1 nie istnieje lub błąd"
echo ""

echo "--- 2.3. Data utworzenia kontenera nc-postgres-1 ---"
docker inspect nc-postgres-1 --format 'Created: {{.Created}}' 2>/dev/null || echo "Kontener nc-postgres-1 nie istnieje"
echo ""

echo "=== 3. INITDB.D - CZY PRZYWRACA STARY DUMP? ==="
echo ""
echo "--- 3.1. Zawartość katalogu initdb.d ---"
if [ -d "/home/pawel/apps/nc/docker/postgres/initdb.d" ]; then
    ls -l /home/pawel/apps/nc/docker/postgres/initdb.d
    echo ""
    echo "--- 3.2. Zawartość plików .sh ---"
    for f in /home/pawel/apps/nc/docker/postgres/initdb.d/*.sh; do
        if [ -f "$f" ]; then
            echo "=== $f ==="
            head -100 "$f"
            echo ""
        fi
    done
    echo "--- 3.3. Zawartość plików .sql (pierwsze 100 linii) ---"
    for f in /home/pawel/apps/nc/docker/postgres/initdb.d/*.sql; do
        if [ -f "$f" ]; then
            echo "=== $f ==="
            head -100 "$f"
            echo ""
        fi
    done
else
    echo "Katalog /home/pawel/apps/nc/docker/postgres/initdb.d NIE ISTNIEJE"
fi
echo ""

echo "=== 4. CRONY / SKRYPTY RSYNC/CP ==="
echo ""
echo "--- 4.1. Cron użytkownika pawel ---"
crontab -l 2>/dev/null || echo "BRAK crona użytkownika"
echo ""

echo "--- 4.2. Systemowe crony (szukanie nc_postgres_data) ---"
sudo grep -R "nc_postgres_data" /etc/cron* 2>/dev/null || echo "BRAK odniesień nc_postgres_data w cronach"
echo ""

echo "--- 4.3. Systemowe crony (szukanie /mnt/data2tb) ---"
sudo grep -R "/mnt/data2tb" /etc/cron* 2>/dev/null || echo "BRAK odniesień /mnt/data2tb w cronach"
echo ""

echo "--- 4.4. Skrypty w /usr/local/bin związane z postgres ---"
ls -l /usr/local/bin/*postgres* /usr/local/bin/*pg_* 2>/dev/null | head -20 || echo "BRAK skryptów postgres w /usr/local/bin"
echo ""

echo "=== 5. HISTORIA MIGRACJI DOCKERA NA /mnt/data2tb ==="
echo ""
echo "--- 5.1. Mount /var/lib/docker ---"
mount | grep '/var/lib/docker' || echo "BRAK mountu /var/lib/docker"
echo ""

echo "--- 5.2. Najnowsze pliki w /var/lib/docker (ostatnie 10) ---"
sudo find /var/lib/docker -type f -printf '%T@ %TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort -rn | head -10 | awk '{print $2" "$3" "$4}' || echo "Błąd lub brak plików"
echo ""

echo "--- 5.3. Najnowsze pliki w /mnt/data2tb/docker (ostatnie 10) ---"
find /mnt/data2tb/docker -type f -printf '%T@ %TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort -rn | head -10 | awk '{print $2" "$3" "$4}' || echo "Błąd lub brak plików"
echo ""

echo "=== 6. DOCKER ROOT DIR ==="
echo ""
echo "--- 6.1. Docker Root Dir ---"
docker info 2>/dev/null | grep -i 'Docker Root Dir' || echo "Nie można pobrać informacji"
echo ""

echo "=== 7. DODATKOWO: SPRAWDZENIE LOGÓW KONTENERA ==="
echo ""
echo "--- 7.1. Ostatnie 50 linii logów nc-postgres-1 (szukanie restore/init) ---"
docker logs nc-postgres-1 2>&1 | tail -50 | grep -iE 'restore|init|dump|backup|recovery' || echo "BRAK wpisów restore/init w logach"
echo ""

echo "=== 8. SPRAWDZENIE DOCKER COMPOSE ==="
echo ""
echo "--- 8.1. Gdzie jest docker-compose.yml dla nc ---"
if [ -f "/home/pawel/apps/nc/docker-compose.yml" ]; then
    echo "Plik: /home/pawel/apps/nc/docker-compose.yml"
    echo "Sekcja volumes dla postgres:"
    grep -A 20 "postgres:" /home/pawel/apps/nc/docker-compose.yml | grep -A 10 "volumes:" || echo "Nie znaleziono sekcji volumes"
else
    echo "Plik docker-compose.yml nie znaleziony w /home/pawel/apps/nc/"
fi
echo ""

echo "=========================================="
echo "DIAGNOZA ZAKOŃCZONA"
echo "=========================================="



