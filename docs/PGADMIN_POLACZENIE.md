# Instrukcja połączenia z bazami danych w pgAdmin

## ⚠️ Ważne: Cloudflare i połączenia TCP

**Cloudflare NIE obsługuje połączeń TCP** (tylko HTTP/HTTPS), więc **nie można** użyć subdomeny Cloudflare do bezpośredniego połączenia z PostgreSQL.

**Rozwiązanie**: Użyj **SSH Tunnel** (najbezpieczniejsze i zalecane).

## 🔑 Dostęp do serwera - jeśli nie pamiętasz hasła

### Opcja 1: Użyj klucza SSH (zalecane - bez hasła)

Serwer jest skonfigurowany do używania **kluczy SSH zamiast hasła**. Jeśli masz skonfigurowany klucz SSH, możesz łączyć się bez hasła:

```bash
# Sprawdź, czy masz klucz SSH:
ls -la ~/.ssh/id_*

# Jeśli masz klucz (np. id_ed25519, id_rsa), po prostu użyj:
ssh pawel@212.127.93.27

# Lub użyj skryptu z projektu:
./scripts/ssh-vps.sh
```

**Jeśli nie masz klucza SSH lub nie działa:**
1. **Sprawdź, czy klucz jest dodany do agenta SSH:**
   ```bash
   ssh-add -l
   ```

2. **Dodaj klucz do agenta:**
   ```bash
   ssh-add ~/.ssh/id_ed25519  # lub id_rsa
   ```

3. **Jeśli nie masz klucza, wygeneruj nowy:**
   ```bash
   ssh-keygen -t ed25519 -C "twoj@email.com"
   ```

4. **Skopiuj klucz na serwer** (wymaga jednorazowego hasła lub innego dostępu):
   ```bash
   ssh-copy-id pawel@212.127.93.27
   ```

### Opcja 2: Odzyskaj/zresetuj hasło SSH

Jeśli masz **fizyczny dostęp do serwera** lub **dostęp przez konsolę (VPS provider)**:

1. **Zaloguj się przez konsolę** (bezpośrednio na serwerze lub przez panel VPS)
2. **Zresetuj hasło:**
   ```bash
   sudo passwd pawel
   ```

3. **Lub jeśli jesteś rootem:**
   ```bash
   passwd pawel
   ```

### Opcja 3: Alternatywne metody dostępu

**Jeśli masz dostęp do Portainer lub innego narzędzia zarządzania:**
- Możesz użyć Portainer do wykonania komend w kontenerach
- Możesz użyć Portainer do dostępu do terminala kontenera

**Jeśli masz dostęp do pgAdmin przez Cloudflare:**
- Możesz użyć pgAdmin bezpośrednio (ale połączenia do baz nadal wymagają SSH tunnel)

### Opcja 4: Sprawdź zapisane hasła

**Sprawdź, czy masz zapisane hasła w:**
- Menedżerze haseł (np. LastPass, 1Password, Bitwarden)
- Plikach konfiguracyjnych projektu (ale hasła nie powinny być commitowane)
- Notatkach/dokumentacji

**Pliki, które mogą zawierać informacje o dostępie:**
- `ansible/inventories/prod/group_vars/secrets.yml` (ale to hasła do baz, nie SSH)
- Dokumentacja projektu
- Notatki osobiste

### 🔑 Szybka weryfikacja dostępu SSH

**Sprawdź, czy możesz połączyć się z serwerem:**

```bash
# Sprawdź, czy masz klucz SSH:
ls -la ~/.ssh/id_*

# Spróbuj połączyć się (bez hasła, jeśli masz klucz):
ssh pawel@212.127.93.27
```

**Jeśli działa bez hasła** → masz klucz SSH, możesz użyć SSH Tunnel.

**Jeśli prosi o hasło** → sprawdź sekcję "Dostęp do serwera" poniżej.

---

### Szybki start - SSH Tunnel

#### Jeśli już masz SSH Tunnel (np. dla nc-postgres-test):

1. **Sprawdź, czy tunel działa:**
   ```bash
   ss -tlnp | grep 127.0.0.1 | grep -E "5432|5433|5050"
   ```

2. **W pgAdmin użyj**:
   - Host: `localhost` (nie IP serwera!)
   - Port: `5432` dla produkcji, `5433` dla testu

3. **Jeśli potrzebujesz dodać kolejne porty** (np. 5432 dla produkcji lub 5050 dla pgAdmin):
   - Zatrzymaj obecny tunel (Ctrl+C)
   - Uruchom z wszystkimi portami: `ssh -L 5432:localhost:5432 -L 5433:localhost:5433 -L 5050:localhost:5050 -N pawel@212.127.93.27`

#### Jeśli nie masz jeszcze SSH Tunnel:

1. **Upewnij się, że masz dostęp SSH** (patrz sekcja "Dostęp do serwera" wyżej)

2. **Utwórz tunel** (na lokalnym komputerze):
   ```bash
   ssh -L 5432:localhost:5432 -L 5433:localhost:5433 -L 5050:localhost:5050 -N pawel@212.127.93.27
   ```
   (Zastąp `212.127.93.27` swoim IP serwera)
   
   **Jeśli używasz klucza SSH:**
   - Komenda zadziała automatycznie (bez pytania o hasło)
   
   **Jeśli używasz hasła:**
   - Zostaniesz poproszony o hasło SSH (nie hasło do bazy!)

2. **W pgAdmin użyj**:
   - Host: `localhost` (nie IP serwera!)
   - Port: `5432` dla produkcji, `5433` dla testu

3. **Zostaw terminal otwarty** - tunel musi być aktywny podczas pracy.

Szczegółowe instrukcje poniżej ↓

---

## Informacje o serwerach

### 1. nc-postgres-1 (Produkcja)
- **Host/Adres**: `localhost` (lub IP serwera)
- **Port**: `5432`
- **Użytkownik**: `pawel`
- **Hasło**: `Relisys17!`
- **Dostępne bazy danych**:
  - `MPD`
  - `default`
  - `matterhorn1`
  - `web_agent`
  - `postgres`

### 2. nc-postgres-test (Test)
- **Host/Adres**: `localhost` (lub IP serwera)
- **Port**: `5433`
- **Użytkownik**: `pawel` (lub `testuser`)
- **Hasło**: `Relisys17!` (dla użytkownika `pawel`) lub `testpass123` (dla `testuser`)
- **Dostępne bazy danych**:
  - `default`
  - `zzz_MPD`
  - `zzz_default`
  - `zzz_matterhorn1`
  - `zzz_web_agent`
  - `zzz_wega`
  - `postgres`

## pgAdmin - dostęp

pgAdmin jest dostępny na porcie **5050**:

### Jeśli łączysz się lokalnie (z serwera VPS):
- **URL**: `http://localhost:5050`
- **Email i hasło**: Zdefiniowane w `ansible/inventories/prod/group_vars/secrets.yml` (zmienne `pgadmin_email` i `pgadmin_password`)

### Jeśli łączysz się zdalnie (z innego komputera):

**Opcja 1: Przez SSH Tunnel (zalecane)**
1. Utwórz SSH tunnel dla pgAdmin: `ssh -L 5050:localhost:5050 -N user@IP_SERWERA`
2. Otwórz w przeglądarce: `http://localhost:5050`

**Opcja 2: Przez subdomenę Cloudflare (jeśli skonfigurowana)**
- Jeśli masz skonfigurowaną subdomenę dla pgAdmin (np. `pgadmin.sowa.ch`) w Nginx Proxy Manager:
- **URL**: `https://pgadmin.sowa.ch`
- Cloudflare obsługuje HTTP/HTTPS, więc pgAdmin przez przeglądarkę może działać przez Cloudflare

⚠️ **Uwaga**: Nawet jeśli pgAdmin jest dostępny przez Cloudflare, **połączenia do baz danych w pgAdmin nadal wymagają SSH Tunnel**, bo pgAdmin łączy się z PostgreSQL przez TCP.

## Krok po kroku - dodanie serwerów w pgAdmin

### Krok 1: Otwórz pgAdmin
1. Otwórz przeglądarkę i przejdź do `http://localhost:5050` (lub odpowiedniego adresu)
2. Zaloguj się używając email i hasła z konfiguracji

### ⚠️ WAŻNE: SSH Tunnel w pgAdmin vs zewnętrzny SSH Tunnel

pgAdmin ma **wbudowaną funkcję SSH Tunnel**. Masz dwie opcje:

**Opcja 1: Wbudowany SSH Tunnel w pgAdmin (ZALECANE)**
- Włącz "Use SSH tunneling" w zakładce "SSH Tunnel"
- W zakładce "Connection" użyj **`localhost`** jako host (nie IP serwera!)
- pgAdmin automatycznie tworzy tunel SSH

**Opcja 2: Zewnętrzny SSH Tunnel (z terminala)**
- Wyłącz "Use SSH tunneling" w zakładce "SSH Tunnel"
- Uruchom tunel w terminalu: `ssh -L 5433:localhost:5433 -N pawel@212.127.93.27`
- W zakładce "Connection" użyj **`localhost`** jako host

**NIGDY nie używaj IP serwera (`212.127.93.27`) w zakładce "Connection" jeśli masz włączony SSH Tunnel!**

### Krok 2: Dodaj serwer produkcyjny (nc-postgres-1)

#### Opcja A: Używasz wbudowanego SSH Tunnel w pgAdmin (ZALECANE)

1. Kliknij prawym przyciskiem na **"Servers"** w lewym panelu
2. Wybierz **"Register" → "Server..."**
3. W zakładce **"General"**:
   - **Name**: `nc-postgres-1 (Produkcja)`
4. W zakładce **"SSH Tunnel"**:
   - ✅ **Use SSH tunneling**: WŁĄCZ (przełącz na niebieski)
   - **Tunnel host**: `212.127.93.27` (IP serwera)
   - **Tunnel port**: `22` (port SSH)
   - **Username**: `pawel` (użytkownik SSH)
   - **Authentication**: Wybierz **"Password"**
   - **Password**: Wpisz hasło SSH (to hasło do serwera, nie do bazy!)
   - ✅ **Save password** (opcjonalnie, ale zalecane)
5. W zakładce **"Connection"**:
   - **Host name/address**: `localhost` ⚠️ **WAŻNE**: Użyj `localhost` (nie IP serwera!), bo pgAdmin używa SSH Tunnel
   - **Port**: `5432`
   - **Maintenance database**: `postgres`
   - **Username**: `pawel` (użytkownik bazy PostgreSQL)
   - **Password**: `Relisys17!` (hasło do bazy PostgreSQL)
   - ✅ Zaznacz **"Save password"** (opcjonalnie)
6. Kliknij **"Save"**

#### Opcja B: Używasz zewnętrznego SSH Tunnel (z terminala)

1. Kliknij prawym przyciskiem na **"Servers"** w lewym panelu
2. Wybierz **"Register" → "Server..."**
3. W zakładce **"General"**:
   - **Name**: `nc-postgres-1 (Produkcja)`
4. W zakładce **"SSH Tunnel"**:
   - ❌ **Use SSH tunneling**: WYŁĄCZ (szary przełącznik)
5. W zakładce **"Connection"**:
   - **Host name/address**: `localhost` ⚠️ **WAŻNE**: Użyj `localhost` (nie IP serwera!), bo używasz zewnętrznego tunelu
   - **Port**: `5432`
   - **Maintenance database**: `postgres`
   - **Username**: `pawel`
   - **Password**: `Relisys17!`
   - ✅ Zaznacz **"Save password"** (opcjonalnie)
6. Kliknij **"Save"**

⚠️ **Uwaga**: 
- Jeśli używasz **wbudowanego SSH Tunnel w pgAdmin** → w "Connection" użyj `localhost`
- Jeśli używasz **zewnętrznego SSH Tunnel** (z terminala) → w "Connection" też użyj `localhost`
- **NIGDY nie używaj IP serwera** (`212.127.93.27`) w "Connection" jeśli masz SSH Tunnel!

### Krok 3: Dodaj serwer testowy (nc-postgres-test)

#### Opcja A: Używasz wbudowanego SSH Tunnel w pgAdmin (ZALECANE)

1. Kliknij prawym przyciskiem na **"Servers"** w lewym panelu
2. Wybierz **"Register" → "Server..."**
3. W zakładce **"General"**:
   - **Name**: `nc-postgres-test (Test)`
4. W zakładce **"SSH Tunnel"**:
   - ✅ **Use SSH tunneling**: WŁĄCZ (przełącz na niebieski)
   - **Tunnel host**: `212.127.93.27` (IP serwera)
   - **Tunnel port**: `22` (port SSH)
   - **Username**: `pawel` (użytkownik SSH)
   - **Authentication**: Wybierz **"Password"**
   - **Password**: Wpisz hasło SSH (to hasło do serwera, nie do bazy!)
   - ✅ **Save password** (opcjonalnie, ale zalecane)
5. W zakładce **"Connection"**:
   - **Host name/address**: `localhost` ⚠️ **WAŻNE**: Użyj `localhost` (nie IP serwera!), bo pgAdmin używa SSH Tunnel
   - **Port**: `5433`
   - **Maintenance database**: `postgres`
   - **Username**: `pawel` (użytkownik bazy PostgreSQL)
   - **Password**: `Relisys17!` (hasło do bazy PostgreSQL)
   - ✅ Zaznacz **"Save password"** (opcjonalnie)
6. Kliknij **"Save"**

#### Opcja B: Używasz zewnętrznego SSH Tunnel (z terminala)

1. Kliknij prawym przyciskiem na **"Servers"** w lewym panelu
2. Wybierz **"Register" → "Server..."**
3. W zakładce **"General"**:
   - **Name**: `nc-postgres-test (Test)`
4. W zakładce **"SSH Tunnel"**:
   - ❌ **Use SSH tunneling**: WYŁĄCZ (szary przełącznik)
5. W zakładce **"Connection"**:
   - **Host name/address**: `localhost` ⚠️ **WAŻNE**: Użyj `localhost` (nie IP serwera!), bo używasz zewnętrznego tunelu
   - **Port**: `5433`
   - **Maintenance database**: `postgres`
   - **Username**: `pawel`
   - **Password**: `Relisys17!`
   - ✅ Zaznacz **"Save password"** (opcjonalnie)
6. Kliknij **"Save"**

⚠️ **Uwaga**: 
- Jeśli używasz **wbudowanego SSH Tunnel w pgAdmin** → w "Connection" użyj `localhost`
- Jeśli używasz **zewnętrznego SSH Tunnel** (z terminala) → w "Connection" też użyj `localhost`
- **NIGDY nie używaj IP serwera** (`212.127.93.27`) w "Connection" jeśli masz SSH Tunnel!

## Połączenie zdalne (z Cloudflare i subdomenami)

⚠️ **WAŻNE**: Cloudflare **NIE obsługuje połączeń TCP** (tylko HTTP/HTTPS), więc **nie można** użyć subdomeny Cloudflare do bezpośredniego połączenia z PostgreSQL. Bezpośrednie połączenie przez IP również może nie działać, jeśli Cloudflare blokuje porty.

### Rozwiązanie 1: SSH Tunnel (ZALECANE - najbezpieczniejsze)

SSH Tunnel tworzy bezpieczne połączenie przez SSH i przekierowuje porty lokalnie.

#### Jeśli już masz SSH Tunnel

Jeśli już masz aktywny SSH tunnel (np. dla nc-postgres-test), możesz:

1. **Sprawdź, które porty są już przekierowane:**
   ```bash
   # Sprawdź aktywne tunele
   netstat -an | grep LISTEN | grep 127.0.0.1
   # lub
   ss -tlnp | grep 127.0.0.1
   ```

2. **W pgAdmin użyj `localhost` jako host:**
   - Jeśli masz tunel na porcie 5433 → użyj `localhost:5433` dla nc-postgres-test
   - Jeśli masz tunel na porcie 5432 → użyj `localhost:5432` dla nc-postgres-1

3. **Jeśli potrzebujesz dodać kolejne porty do istniejącego tunelu:**
   - Zatrzymaj obecny tunel (Ctrl+C)
   - Uruchom nowy z wszystkimi potrzebnymi portami (patrz poniżej)

#### Krok 1: Utwórz SSH Tunnel

Na swoim lokalnym komputerze uruchom:

```bash
# Dla nc-postgres-1 (produkcja)
ssh -L 5432:localhost:5432 -N user@IP_SERWERA

# Dla nc-postgres-test (test) - w osobnym terminalu
ssh -L 5433:localhost:5433 -N user@IP_SERWERA

# Dla pgAdmin - w osobnym terminalu
ssh -L 5050:localhost:5050 -N user@IP_SERWERA
```

**Lub wszystkie w jednym tunelu (zalecane):**
```bash
ssh -L 5432:localhost:5432 -L 5433:localhost:5433 -L 5050:localhost:5050 -N user@IP_SERWERA
```

**Jeśli już masz tunel i chcesz tylko dodać kolejne porty:**
```bash
# Zatrzymaj obecny tunel (Ctrl+C w terminalu gdzie działa)
# Następnie uruchom z wszystkimi portami:
ssh -L 5432:localhost:5432 -L 5433:localhost:5433 -L 5050:localhost:5050 -N user@IP_SERWERA
```

**Gdzie:**
- `user` - Twój użytkownik SSH na serwerze (prawdopodobnie `pawel`)
- `IP_SERWERA` - IP serwera VPS (np. `212.127.93.27`)

**Opcje:**
- `-L` - tworzy lokalny port forwarding
- `-N` - nie wykonuje żadnych komend, tylko utrzymuje połączenie
- `-f` - uruchamia w tle (opcjonalnie)

#### Krok 2: Połącz się w pgAdmin używając localhost

Teraz w pgAdmin użyj:
- **Host name/address**: `localhost` (nie IP serwera!)
- **Port**: `5432` dla nc-postgres-1 lub `5433` dla nc-postgres-test

SSH tunnel automatycznie przekieruje połączenie na serwer.

#### Krok 3: Utrzymaj tunel otwarty

Tunel musi być otwarty podczas pracy z bazą. Możesz:
- Zostaw terminal otwarty
- Uruchom w tle: `ssh -f -L 5432:localhost:5432 -L 5433:localhost:5433 -L 5050:localhost:5050 -N user@IP_SERWERA`
- Użyj `screen` lub `tmux` do zarządzania sesjami

#### Weryfikacja tunelu

Sprawdź, czy tunel działa:
```bash
# Sprawdź czy porty są nasłuchiwane lokalnie
netstat -an | grep 5432
netstat -an | grep 5433
netstat -an | grep 5050

# Lub użyj ss (nowsze systemy)
ss -tlnp | grep 5432
```

Jeśli widzisz `127.0.0.1:5432` w stanie LISTEN, tunel działa poprawnie.

### Rozwiązanie 2: Cloudflare Tunnel (zaawansowane)

Jeśli masz skonfigurowany Cloudflare Tunnel, możesz dodać PostgreSQL do tunelu:

1. **Zainstaluj Cloudflare Tunnel** (jeśli jeszcze nie masz)
2. **Dodaj konfigurację** w `config.yml`:
   ```yaml
   ingress:
     - hostname: postgres.sowa.ch
       service: tcp://localhost:5432
     - hostname: postgres-test.sowa.ch
       service: tcp://localhost:5433
   ```
3. **W pgAdmin użyj**: `postgres.sowa.ch` jako host (port 5432)

⚠️ **Uwaga**: Cloudflare Tunnel wymaga dodatkowej konfiguracji i może mieć limity.

### Rozwiązanie 3: VPN (jeśli dostępne)

Jeśli masz VPN do sieci serwera:
- Połącz się przez VPN
- Użyj lokalnego IP serwera w pgAdmin (np. `192.168.1.100`)

### Rozwiązanie 4: Bezpośrednie połączenie przez IP (jeśli dostępne)

Jeśli masz bezpośredni dostęp do IP serwera (bez Cloudflare):

1. **Host name/address**: Użyj IP serwera VPS (np. `212.127.93.27`)
2. **Upewnij się, że porty są dostępne**:
   - Port `5432` dla nc-postgres-1
   - Port `5433` dla nc-postgres-test
   - Port `5050` dla pgAdmin

3. **Sprawdź firewall**:
   ```bash
   sudo ufw status
   sudo ufw allow 5432/tcp  # Dla nc-postgres-1
   sudo ufw allow 5433/tcp  # Dla nc-postgres-test
   sudo ufw allow 5050/tcp  # Dla pgAdmin
   ```

⚠️ **UWAGA BEZPIECZEŃSTWA**: Otwieranie portów PostgreSQL publicznie jest **niebezpieczne**. Używaj tylko w zaufanych sieciach lub z dodatkowymi zabezpieczeniami (fail2ban, IP whitelist).

## Weryfikacja połączenia

Po dodaniu serwerów, możesz:
1. Rozwinąć serwer w lewym panelu
2. Rozwinąć **"Databases"**
3. Zobaczysz listę dostępnych baz danych
4. Kliknij na bazę danych, aby zobaczyć tabele, schematy itp.

## Uwagi bezpieczeństwa

⚠️ **WAŻNE**: 
- **Cloudflare NIE obsługuje połączeń TCP** - nie można użyć subdomeny do bezpośredniego połączenia z PostgreSQL
- **SSH Tunnel jest najbezpieczniejszym rozwiązaniem** - szyfruje całe połączenie i nie wymaga otwierania portów publicznie
- Nie udostępniaj portów PostgreSQL publicznie bez odpowiedniego zabezpieczenia
- Używaj VPN lub SSH tunnel do bezpiecznego połączenia zdalnego

## Rozwiązywanie problemów

### Problem: "Nie pamiętam hasła do serwera SSH"
- **Sprawdź, czy masz klucz SSH** (patrz sekcja "Dostęp do serwera" wyżej)
- Jeśli masz klucz SSH, nie potrzebujesz hasła - użyj: `ssh pawel@212.127.93.27`
- Jeśli nie masz klucza, użyj konsoli VPS lub zresetuj hasło (patrz sekcja "Dostęp do serwera")

### Problem: "Permission denied (publickey)" przy SSH
- **Brak klucza SSH na serwerze** - musisz dodać swój klucz publiczny do `~/.ssh/authorized_keys` na serwerze
- **Sprawdź klucz lokalnie:**
  ```bash
  cat ~/.ssh/id_ed25519.pub  # lub id_rsa.pub
  ```
- **Dodaj klucz na serwerze** (wymaga jednorazowego dostępu):
  ```bash
  ssh-copy-id pawel@212.127.93.27
  ```

### Problem: "Connection refused" lub "Connection timeout"
- **Jeśli używasz Cloudflare**: Cloudflare nie obsługuje TCP - użyj SSH Tunnel (patrz wyżej)
- Sprawdź, czy kontenery działają: `docker ps | grep postgres`
- Sprawdź, czy porty są wystawione: `docker ps | grep postgres`
- Jeśli używasz SSH Tunnel: upewnij się, że tunel jest aktywny i używasz `localhost` jako host
- **Sprawdź, czy SSH działa:** `ssh pawel@212.127.93.27` (powinno działać bez hasła, jeśli masz klucz)

### Problem: "Cloudflare blokuje połączenie"
- Cloudflare proxy obsługuje tylko HTTP/HTTPS (porty 80/443)
- PostgreSQL używa TCP (porty 5432/5433) - Cloudflare nie może tego obsłużyć
- **Rozwiązanie**: Użyj SSH Tunnel (patrz sekcja "Połączenie zdalne")

### Problem: "server closed the connection unexpectedly" lub "connection to server at 127.0.0.1, port XXXX failed"

Ten błąd oznacza, że **SSH Tunnel w pgAdmin nie działa poprawnie**. Port XXXX (np. 34353) to wewnętrzny port pgAdmin przez tunel.

**Rozwiązanie krok po kroku:**

1. **Sprawdź konfigurację SSH Tunnel w pgAdmin:**
   - Otwórz właściwości serwera (prawy klik → Properties)
   - Przejdź do zakładki **"SSH Tunnel"**
   - Sprawdź:
     - ✅ **Use SSH tunneling**: WŁĄCZONE
     - **Tunnel host**: `212.127.93.27` (IP serwera)
     - **Tunnel port**: `22`
     - **Username**: `pawel`
     - **Authentication**: Password
     - **Password**: (sprawdź, czy hasło SSH jest poprawne)

2. **Przetestuj połączenie SSH ręcznie:**
   ```bash
   # Spróbuj połączyć się przez SSH:
   ssh pawel@212.127.93.27
   
   # Jeśli działa → SSH jest OK
   # Jeśli nie działa → sprawdź hasło SSH
   ```

3. **Sprawdź, czy PostgreSQL działa na serwerze:**
   ```bash
   # Zaloguj się na serwer i sprawdź:
   ssh pawel@212.127.93.27
   docker ps | grep postgres
   # Powinny być widoczne: nc-postgres-1 i nc-postgres-test
   ```

4. **Przetestuj połączenie lokalnie na serwerze:**
   ```bash
   # Zaloguj się na serwer:
   ssh pawel@212.127.93.27
   
   # Przetestuj połączenie do bazy testowej:
   docker exec nc-postgres-test psql -U pawel -d postgres -c "SELECT version();"
   
   # Przetestuj połączenie do bazy produkcyjnej:
   docker exec nc-postgres-1 psql -U pawel -d postgres -c "SELECT version();"
   ```

5. **Alternatywa: Użyj zewnętrznego SSH Tunnel zamiast wbudowanego:**
   - W pgAdmin: **SSH Tunnel** → **Use SSH tunneling**: WYŁĄCZ
   - W terminalu uruchom:
     ```bash
     ssh -L 5433:localhost:5433 -N pawel@212.127.93.27
     ```
   - W pgAdmin: **Connection** → **Host name/address**: `localhost`
   - **Port**: `5433` (dla test) lub `5432` (dla produkcji)

6. **Sprawdź logi pgAdmin:**
   - W pgAdmin: **File** → **Preferences** → **Miscellaneous** → **Show logs**
   - Sprawdź, czy są błędy związane z SSH

7. **Jeśli używasz hasła SSH:**
   - Upewnij się, że hasło jest poprawne
   - Spróbuj ponownie wpisać hasło w zakładce "SSH Tunnel"
   - Sprawdź, czy "Save password" jest włączone

8. **Jeśli używasz klucza SSH:**
   - W zakładce "SSH Tunnel" wybierz **"Identity file"** zamiast "Password"
   - Wskaż ścieżkę do klucza prywatnego (np. `~/.ssh/id_ed25519`)

### Problem: "Authentication failed" (w pgAdmin)
- Sprawdź hasło w `ansible/inventories/prod/group_vars/secrets.yml`
- Upewnij się, że używasz poprawnego użytkownika (`pawel`)
- **Uwaga**: To hasło do bazy PostgreSQL, nie do SSH!
- **Jeśli używasz SSH Tunnel**: Upewnij się, że hasło SSH (w zakładce "SSH Tunnel") jest inne niż hasło do bazy (w zakładce "Connection")

### Problem: Nie widzę baz danych
- Upewnij się, że używasz użytkownika z odpowiednimi uprawnieniami
- Sprawdź, czy bazy istnieją: `docker exec nc-postgres-1 psql -U pawel -c "\l"`
