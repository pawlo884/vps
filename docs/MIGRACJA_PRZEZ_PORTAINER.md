# Migracja kontenera nc-postgres-test przez Portainer

## Sytuacja

Kontener `nc-postgres-test` jest widoczny w Portainerze, ale nie jest dostępny bezpośrednio w terminalu. To oznacza, że Portainer łączy się z innym hostem Docker lub kontener jest w innym kontekście.

## Rozwiązania

### Opcja A: Migracja przez Portainer UI

1. **Zrób backup danych:**
   - Otwórz kontener `nc-postgres-test` w Portainerze
   - Kliknij na zakładkę "Console" lub "Exec"
   - Uruchom backup:
     ```bash
     pg_dumpall -U testuser > /tmp/backup.sql
     ```
   - Lub przez terminal hosta (jeśli masz dostęp):
     ```bash
     docker exec nc-postgres-test pg_dumpall -U testuser > backup_$(date +%Y%m%d).sql
     ```

2. **Zatrzymaj kontener:**
   - W Portainerze: Wybierz kontener → "Stop"

3. **Usuń kontener:**
   - W Portainerze: Wybierz kontener → "Remove"

4. **Utwórz nowy kontener przez docker-compose:**
   - Na serwerze gdzie działa Portainer, uruchom:
     ```bash
     cd ~/vps/stacks/test-postgres
     docker compose up -d
     ```

### Opcja B: Migracja przez SSH na właściwy serwer

Jeśli wiesz, na którym serwerze działa Portainer:

1. **Połącz się z serwerem:**
   ```bash
   ssh pawel@ADRES_SERWERA
   ```

2. **Skopiuj pliki konfiguracyjne** (jeśli nie są już tam):
   ```bash
   # Z lokalnego komputera:
   scp -r ~/vps/stacks/test-postgres/ pawel@ADRES_SERWERA:~/vps/stacks/
   ```

3. **Uruchom migrację:**
   ```bash
   ~/vps/scripts/migrate-test-postgres-direct.sh
   ```

### Opcja C: Migracja ręczna (krok po kroku)

1. **Zatrzymaj kontener:**
   ```bash
   docker stop nc-postgres-test
   ```

2. **Zapisz informacje o volume:**
   ```bash
   docker inspect nc-postgres-test --format '{{range .Mounts}}{{.Name}} {{end}}'
   ```

3. **Zapisz konfigurację (użytkownik, hasło, baza):**
   ```bash
   docker inspect nc-postgres-test --format '{{range .Config.Env}}{{println .}}{{end}}' | grep POSTGRES
   ```

4. **Usuń kontener (volume pozostanie):**
   ```bash
   docker rm nc-postgres-test
   ```

5. **Zaktualizuj docker-compose.yml** z właściwym volume i hasłem

6. **Uruchom nowy kontener:**
   ```bash
   cd ~/vps/stacks/test-postgres
   docker compose up -d
   ```

## Sprawdzenie adresu serwera Portainera

Aby znaleźć serwer, gdzie działa kontener:

1. W Portainerze: Sprawdź ustawienia → "Endpoints"
2. Zobacz adres IP/host Docker endpoint
3. Połącz się z tym serwerem przez SSH

## Alternatywnie: Szybka poprawka bez migracji

Jeśli nie możesz zrobić pełnej migracji, możesz dodać tylko TCP keepalive do istniejącego kontenera:

1. W Portainerze: Otwórz konsolę kontenera
2. Edytuj postgresql.conf:
   ```bash
   docker exec -it nc-postgres-test sh
   echo "tcp_keepalives_idle = 60" >> /var/lib/postgresql/data/postgresql.conf
   echo "tcp_keepalives_interval = 10" >> /var/lib/postgresql/data/postgresql.conf
   echo "tcp_keepalives_count = 5" >> /var/lib/postgresql/data/postgresql.conf
   ```
3. Restartuj kontener

## Kontakt z właściwym serwerem

Jeśli Portainer jest skonfigurowany do łączenia się z innym serwerem (np. przez SSH tunnel lub remote Docker socket), musisz:

1. Sprawdzić konfigurację Portainera
2. Połączyć się z właściwym serwerem
3. Tam uruchomić skrypt migracyjny

## Pomoc

Jeśli masz dostęp do Portainera, możesz też:
- Sprawdzić szczegóły kontenera (wszystkie ustawienia)
- Zobaczyć volume używany przez kontener
- Sprawdzić logi kontenera

