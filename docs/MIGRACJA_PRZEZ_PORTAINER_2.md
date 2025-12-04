# Migracja kontenera nc-postgres-test przez Portainer - KROK PO KROKU

## Sytuacja

- Kontener `nc-postgres-test` jest widoczny w Portainerze
- Nie jest w żadnym stacku (utworzony przez Ansible, ale nie zarządzany przez docker-compose)
- Musisz dodać optymalizacje z analizy

## Rozwiązanie: Migracja przez Portainer UI

### KROK 1: Zrób backup danych

W Portainerze:
1. Otwórz kontener `nc-postgres-test`
2. Kliknij na zakładkę "Console"
3. Kliknij "Connect" aby otworzyć terminal w kontenerze
4. Wykonaj backup:
   ```bash
   pg_dumpall -U testuser > /tmp/backup_$(date +%Y%m%d).sql
   ```
5. Skopiuj backup na host:
   ```bash
   docker cp nc-postgres-test:/tmp/backup_*.sql ./
   ```

### KROK 2: Zatrzymaj kontener

W Portainerze:
1. W liście kontenerów znajdź `nc-postgres-test`
2. Zatrzymaj kontener (przycisk "Stop")

### KROK 3: Zapisz informacje o volume

W Portainerze:
1. Otwórz kontener `nc-postgres-test`
2. Przejdź do zakładki "Volumes"
3. Zapisz nazwę volume (prawdopodobnie `nc_postgres_test_data`)

### KROK 4: Usuń kontener (OPCJONALNIE)

UWAGA: Volume z danymi zostanie zachowany!

W Portainerze:
1. Zatrzymaj kontener (jeśli jeszcze działa)
2. Usuń kontener (przycisk "Remove")
3. NIE zaznaczaj "Remove the volumes" - zostaw volume z danymi!

### KROK 5: Przygotuj pliki na serwerze

Na serwerze gdzie działa Portainer, uruchom:

```bash
# Upewnij się, że pliki są skopiowane
cd ~/vps/stacks/test-postgres
ls -la
# Powinieneś zobaczyć:
# - docker-compose.yml
# - postgresql.conf
```

Jeśli plików nie ma, skopiuj je z lokalnego komputera:

```bash
# Z lokalnego komputera (WSL):
scp -r ~/vps/stacks/test-postgres/ pawel@SERWER:~/vps/stacks/
```

### KROK 6: Edytuj hasło

Na serwerze:

```bash
cd ~/vps/stacks/test-postgres
nano docker-compose.yml
# Znajdź linię 9: POSTGRES_PASSWORD: test_password
# Zmień na właściwe hasło
```

### KROK 7: Uruchom nowy kontener

Na serwerze:

```bash
cd ~/vps/stacks/test-postgres
docker compose up -d
```

### KROK 8: Sprawdź czy działa

```bash
docker compose ps
docker compose logs -f postgres-test
```

### KROK 9: Weryfikacja w Portainerze

W Portainerze powinieneś teraz zobaczyć:
- Kontener `nc-postgres-test` w stacku `test-postgres`
- Status: "healthy" (po chwili)
- Wszystkie optymalizacje zastosowane

## Alternatywnie: Przez Stack w Portainerze

Możesz też utworzyć nowy stack w Portainerze:

1. W Portainerze: Stacks → "Add stack"
2. Nazwa: `test-postgres`
3. Wklej zawartość `docker-compose.yml` (ze zmienionym hasłem)
4. Upload plików: Dodaj `postgresql.conf`
5. Deploy the stack

## Co zostało zrobione

✅ Kontener używa nowej konfiguracji z optymalizacjami
✅ Healthcheck jest aktywny
✅ TCP Keepalive jest skonfigurowany
✅ Limity logowania są ustawione
✅ Limity zasobów są aktywne
✅ **Wszystkie dane są zachowane** (ten sam volume)

