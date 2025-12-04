# Instrukcja migracji kontenera nc-postgres-test (Opcja 2)

## ⚠️ Ważne przed rozpoczęciem

Kontener `nc-postgres-test` istnieje i działa na Twoim serwerze (widoczny w Portainerze). 
Przed migracją **zrób backup danych**!

## 📋 Krok po kroku

### Krok 1: Połącz się z serwerem

```bash
ssh pawel@192.168.50.31
# lub inny adres Twojego serwera VPS
```

### Krok 2: Sprawdź kontener

```bash
docker ps -a | grep nc-postgres-test
```

Powinieneś zobaczyć kontener w stanie `running`.

### Krok 3: Zrób backup danych (OPCJONALNIE, ale zalecane)

```bash
# Backup całego volume
docker run --rm -v nc_postgres_test_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/postgres_test_backup_$(date +%Y%m%d_%H%M%S).tar.gz /data

# Lub backup bazy danych
docker exec nc-postgres-test pg_dumpall -U testuser > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Krok 4: Upewnij się, że pliki konfiguracyjne są na serwerze

Pliki powinny być w:
```
~/vps/stacks/test-postgres/
├── docker-compose.yml
├── postgresql.conf
└── README.md
```

Jeśli nie ma, skopiuj je z lokalnego komputera:

```bash
# Na lokalnym komputerze (WSL):
scp -r ~/vps/stacks/test-postgres/ pawel@192.168.50.31:~/vps/stacks/
```

### Krok 5: Uruchom skrypt migracyjny

```bash
~/vps/scripts/migrate-test-postgres-remote.sh
```

Skrypt:
- ✅ Sprawdzi czy kontener istnieje
- ✅ Zatrzyma kontener
- ✅ Pokaże informacje o volume z danymi
- ✅ Zaproponuje usunięcie starego kontenera
- ✅ Pokaże następne kroki

### Krok 6: Edytuj hasło w docker-compose.yml

```bash
cd ~/vps/stacks/test-postgres
nano docker-compose.yml
# lub
vi docker-compose.yml
```

Znajdź linię 9 i ustaw właściwe hasło:
```yaml
POSTGRES_PASSWORD: twoje_haslo_tutaj
```

### Krok 7: Sprawdź konfigurację volume

Jeśli stary kontener używał innego volume, musisz zaktualizować `docker-compose.yml`.

Sprawdź jaki volume używał stary kontener:
```bash
docker inspect nc-postgres-test --format '{{range .Mounts}}{{.Name}} {{end}}'
```

Jeśli volume nazywa się inaczej niż `nc_postgres_test_data`, zaktualizuj w `docker-compose.yml`:
```yaml
volumes:
  - nazwa_twojego_volume:/var/lib/postgresql/data
```

### Krok 8: Uruchom nowy kontener

```bash
cd ~/vps/stacks/test-postgres
docker compose up -d
```

### Krok 9: Sprawdź czy działa

```bash
# Status
docker compose ps

# Logi
docker compose logs -f postgres-test

# Test połączenia
docker exec nc-postgres-test psql -U testuser -d testdb -c "SELECT version();"
```

## ✅ Co zostało zrobione

Po migracji:
- ✅ Kontener używa nowej konfiguracji z optymalizacjami
- ✅ Healthcheck jest aktywny
- ✅ TCP Keepalive jest skonfigurowany
- ✅ Limity logowania są ustawione
- ✅ Limity zasobów są aktywne
- ✅ **Wszystkie dane są zachowane** (ten sam volume)

## 🔍 Rozwiązywanie problemów

### Problem: "Volume nie został znaleziony"

Jeśli docker-compose nie może znaleźć volume, sprawdź:
```bash
docker volume ls | grep postgres
```

I zaktualizuj `docker-compose.yml` z właściwą nazwą volume.

### Problem: "Błąd przy montowaniu postgresql.conf"

Sprawdź czy plik istnieje i ma właściwe uprawnienia:
```bash
ls -la ~/vps/stacks/test-postgres/postgresql.conf
chmod 644 ~/vps/stacks/test-postgres/postgresql.conf
```

### Problem: "Kontener nie startuje"

Sprawdź logi:
```bash
docker compose logs postgres-test
```

## 📝 Notatki

- Port kontenera: **5433** (nie zmieniony)
- Volume: zachowany, dane są bezpieczne
- Stary kontener: usunięty po migracji

## 🆘 Wsparcie

Jeśli coś pójdzie nie tak, możesz przywrócić stary kontener (jeśli nie został usunięty):
```bash
docker start nc-postgres-test
```

Lub przywrócić z backupu (jeśli zrobiłeś backup volume).

