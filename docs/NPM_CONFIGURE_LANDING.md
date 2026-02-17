# Konfiguracja Landing Page w Nginx Proxy Manager

## Problem

Po wejściu na IP serwera (np. `http://212.127.93.27`) widzisz domyślną stronę powitalną Nginx Proxy Manager. To oznacza, że nie ma jeszcze skonfigurowanego Proxy Host.

## Rozwiązanie

Musisz dodać Proxy Host w NPM, który przekieruje ruch na kontener `landing`.

### Krok 1: Zaloguj się do NPM

1. Otwórz w przeglądarce: `http://212.127.93.27:81`
2. Zaloguj się (domyślne dane dostępowe przy pierwszym uruchomieniu):
   - **Email:** `admin@example.com`
   - **Hasło:** `changeme`
   - ⚠️ **Zmień hasło po pierwszym logowaniu!**

### Krok 2: Dodaj Proxy Host dla Landing Page

1. W menu głównym kliknij: **Hosts** → **Proxy Hosts**
2. Kliknij przycisk **Add Proxy Host** (lub **+ Add Proxy Host**)

3. **W zakładce "Details" ustaw:**
   - **Domain Names:** 
     - Jeśli masz domenę (np. `sowa.ch`): wpisz `sowa.ch`
     - Jeśli nie masz domeny i chcesz użyć IP: wpisz `212.127.93.27`
     - ⚠️ **Uwaga:** Bez domeny nie będzie możliwe uzyskanie certyfikatu SSL
   
   - **Scheme:** `http` (domyślnie)
   
   - **Forward Hostname/IP:** `landing` 
     - ⚠️ **WAŻNE:** To nazwa kontenera Docker, który jest w tej samej sieci co NPM
   
   - **Forward Port:** `3000`
     - To port, na którym działa Next.js w kontenerze landing
   
   - ✅ **Block Common Exploits** (zalecane)
   
   - ✅ **Websockets Support** (jeśli potrzebne)

4. **W zakładce "SSL" (jeśli masz domenę):**
   - Wybierz: **Request a new SSL Certificate with Let's Encrypt**
   - ✅ **I Agree to the Let's Encrypt Terms of Service**
   - ✅ **Force SSL** (przekieruj HTTP na HTTPS)
   - ✅ **HTTP/2 Support**
   - ✅ **HSTS Enabled** (opcjonalnie, ale zalecane)
   
   ⚠️ **Bez domeny nie możesz uzyskać certyfikatu SSL z Let's Encrypt!**

5. Kliknij **Save**

### Krok 3: Sprawdź działanie

Po zapisaniu:

```bash
# Sprawdź czy kontener landing działa:
docker ps | grep landing

# Sprawdź czy landing odpowiada:
docker exec landing wget -qO- http://localhost:3000/ | head -20

# Z internetu (jeśli masz domenę):
curl -I http://sowa.ch
# lub
curl -I https://sowa.ch
```

### Krok 4: Jeśli masz domenę - skonfiguruj DNS

Jeśli używasz domeny (np. `sowa.ch`), musisz skonfigurować rekord DNS:

**W panelu DNS (np. Cloudflare, Namecheap):**
- Rekord typu **A**:
  - **Nazwa:** `@` (lub `sowa.ch`)
  - **Wartość:** `212.127.93.27`
  - **TTL:** `3600` (lub Auto)
  
- Opcjonalnie dla subdomen:
  - **Nazwa:** `www`
  - **Wartość:** `212.127.93.27`

Poczekaj 1-5 minut na propagację DNS, a następnie możesz uzyskać certyfikat SSL.

### Krok 5: Przekierowanie z IP na domenę

Jeśli chcesz, aby po wejściu na IP serwera (`http://212.127.93.27`) użytkownik został przekierowany na domenę `sowa.ch`:

⚠️ **SZYBKA INSTRUKCJA (najskuteczniejsza metoda):**

Jeśli masz SSH dostęp do serwera, wykonaj te komendy:

```bash
# 1. Edytuj plik domyślnej konfiguracji NPM
sudo nano /srv/nginx-proxy-manager/data/nginx/default_host.conf

# 2. Wklej następującą zawartość (usuń wszystko co było wcześniej):
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://sowa.ch$request_uri;
}

server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name _;
    return 301 https://sowa.ch$request_uri;
}

# 3. Zapisz (Ctrl+O, Enter, Ctrl+X)

# 4. Zrestartuj kontener NPM
docker restart nginx-proxy-manager

# 5. Sprawdź czy działa
curl -I http://212.127.93.27
```

Jeśli nie masz SSH lub chcesz użyć GUI, użyj poniższych opcji:

#### Opcja A: Ustaw Default Site w NPM (zalecane)

1. **Najpierw utwórz Proxy Host dla `sowa.ch`** (jeśli jeszcze nie masz - patrz Krok 2)

2. **Utwórz Redirect Host:**
   - W menu NPM kliknij: **Hosts** → **Redirect Hosts**
   - Kliknij przycisk **Add Redirect Host**

3. **W zakładce "Details" ustaw:**
   - **Domain Names:** `212.127.93.27` (możesz też dodać `default_server`, ale zwykle nie jest potrzebne)
   - **Forward Hostname/IP:** `sowa.ch`
   - **Forward Port:** `443` (jeśli używasz HTTPS) lub `80` (jeśli HTTP)
   - **Forward Scheme:** `https` (zalecane) lub `http`
   - **Preserve Path:** ✅ (zachowaj ścieżkę URL)
   - **Redirect Type:** `Permanent (301)` (zalecane dla SEO)

4. Kliknij **Save**

5. **Teraz ustaw jako Default Site:**
   - W menu NPM kliknij: **System Settings** (lub **Settings** → **Default Site**)
   - Znajdź opcję **"Default Site"** lub **"404 Page"**
   - Wybierz utworzony Redirect Host dla `212.127.93.27`
   - Lub jeśli nie ma takiej opcji, przejdź do **"Proxy Hosts"** → kliknij na Proxy Host `sowa.ch` → włącz opcję **"Set as Default Site"** (jeśli dostępna)

#### Opcja B: Użyj Proxy Host z Custom Nginx Configuration (jeśli Opcja A nie działa)

Jeśli nie możesz użyć Redirect Host, użyj Proxy Host z przekierowaniem przez Custom Nginx Configuration:

1. W menu NPM kliknij: **Hosts** → **Proxy Hosts** → **Add Proxy Host**

2. **W zakładce "Details":**
   - **Domain Names:** `212.127.93.27` (lub zostaw puste, jeśli nie obsługuje)
   - **Forward Hostname/IP:** `127.0.0.1` (lokalny - nie będzie używane, bo przekierujemy)
   - **Forward Port:** `80`
   - **Forward Scheme:** `http`

3. **W zakładce "Advanced"** dodaj w sekcji **Custom Nginx Configuration:**
   ```nginx
   # Najpierw usuń domyślną konfigurację proxy_pass
   # Następnie przekieruj wszystkie żądania na sowa.ch z zachowaniem ścieżki
   return 301 https://sowa.ch$request_uri;
   ```
   
   ⚠️ **WAŻNE:** Jeśli widzisz w Advanced sekcję z `proxy_pass`, musisz ją całkowicie zastąpić tylko `return 301`.

4. Kliknij **Save**

5. **Sprawdź czy w konfiguracji NPM jest opcja "Catch All" lub "Default":**
   - Przejdź do edycji tego Proxy Host
   - Szukaj opcji typu "Catch All" lub "Default Site" i ją włącz

#### Opcja C: Edytuj bezpośrednio konfigurację Nginx w NPM (zalecane jeśli A i B nie działają)

Jeśli powyższe opcje nie działają, edytuj bezpośrednio plik domyślnej konfiguracji Nginx w NPM:

1. **Sprawdź lokalizację plików NPM:**
   ```bash
   # Sprawdź gdzie NPM przechowuje konfigurację (zazwyczaj):
   ls -la /srv/nginx-proxy-manager/data/nginx/
   ```

2. **Edytuj plik domyślnej konfiguracji:**
   ```bash
   sudo nano /srv/nginx-proxy-manager/data/nginx/default_host.conf
   ```

3. **Zastąp całą zawartość pliku następującą konfiguracją:**
   ```nginx
   server {
       listen 80 default_server;
       listen [::]:80 default_server;
       server_name _;
       
       # Przekieruj wszystkie żądania HTTP na HTTPS sowa.ch
       return 301 https://sowa.ch$request_uri;
   }
   
   server {
       listen 443 ssl http2 default_server;
       listen [::]:443 ssl http2 default_server;
       server_name _;
       
       # Przekieruj wszystkie żądania HTTPS na sowa.ch
       return 301 https://sowa.ch$request_uri;
   }
   ```

4. **Zapisz plik** (Ctrl+O, Enter, Ctrl+X w nano)

5. **Zrestartuj kontener NPM, aby zastosować zmiany:**
   ```bash
   docker restart nginx-proxy-manager
   ```
   
   Lub jeśli używasz docker-compose:
   ```bash
   cd ~/stacks/nginx-proxy-manager
   docker compose restart
   ```

6. **Poczekaj 10-15 sekund** i sprawdź czy działa:
   ```bash
   curl -I http://212.127.93.27
   ```

⚠️ **Uwaga:** 
- Ta metoda może być nadpisana przez NPM przy aktualizacji konfiguracji lub przy niektórych operacjach w GUI
- Jeśli to się stanie, musisz ponownie edytować plik
- Alternatywnie możesz utworzyć skrypt cron, który będzie przywracał tę konfigurację

#### Sprawdzenie działania:

```bash
# Sprawdź przekierowanie:
curl -I http://212.127.93.27

# Powinno zwrócić:
# HTTP/1.1 301 Moved Permanently
# Location: https://sowa.ch/

# Sprawdź też z nagłówkiem Host (jeśli używasz curl z innego serwera):
curl -I -H "Host: 212.127.93.27" http://212.127.93.27
```

#### Ważne uwagi:

- **Jeśli nadal widzisz stronę NPM:** Sprawdź czy masz tylko jeden Proxy/Redirect Host z `212.127.93.27` i czy jest ustawiony jako domyślny
- **Jeśli używasz Cloudflare Proxy:** Cloudflare może cache'ować przekierowania - wyłącz proxy (szara chmurka) dla testów lub poczekaj kilka minut
- **Nie możesz uzyskać certyfikatu SSL dla samego IP** - przekierowanie działa tylko przez HTTP (301/302)
- **HTTPS do IP nie działa:** Jeśli ktoś próbuje wejść na `https://212.127.93.27`, przeglądarka pokaże błąd SSL (`ERR_SSL_UNRECOGNIZED_NAME_ALERT`), ponieważ nie można mieć poprawnego certyfikatu SSL dla IP. To jest oczekiwane zachowanie. Użytkownicy powinni używać `http://212.127.93.27`, które przekieruje na `https://sowa.ch`
- **Jeśli chcesz obsługiwać HTTPS do IP:** Możesz wyłączyć SSL w Redirect Host w GUI NPM (Settings → SSL → None), ale nadal będą problemy, bo przeglądarki wymagają poprawnego certyfikatu dla połączenia HTTPS

## Użycie IP zamiast domeny

Jeśli nie masz domeny i chcesz używać tylko IP:

1. W **Domain Names** wpisz: `212.127.93.27`
2. **Nie możesz** uzyskać certyfikatu SSL (Let's Encrypt wymaga domeny)
3. Strona będzie działać tylko przez HTTP (nie HTTPS)
4. Będzie dostępna pod: `http://212.127.93.27`

⚠️ **Zalecane:** Kup domenę i użyj jej - to umożliwi SSL i profesjonalny wygląd.

## Rozwiązywanie problemów

### Problem: "Bad Gateway" (502) po skonfigurowaniu

**Sprawdź:**
1. Czy kontener `landing` jest uruchomiony:
   ```bash
   docker ps | grep landing
   ```

2. Czy kontener `landing` odpowiada:
   ```bash
   docker exec landing curl -I http://localhost:3000
   ```

3. Czy kontener `landing` jest w tej samej sieci co NPM:
   ```bash
   docker network inspect nginx_proxy_manager_network | grep landing
   ```

4. Sprawdź logi kontenera landing:
   ```bash
   docker logs landing --tail 50
   ```

**Rozwiązanie:**
- Jeśli kontener nie działa: `cd ~/stacks/landing && docker compose up -d`
- Jeśli nie jest w sieci: sprawdź `docker-compose.yml` w `~/stacks/landing/`

### Problem: Strona nie ładuje się

**Sprawdź:**
- Czy Next.js skompilował się poprawnie: `docker logs landing`
- Czy aplikacja odpowiada: `docker exec landing wget -qO- http://localhost:3000/`

### Problem: Nie można uzyskać certyfikatu SSL

**Możliwe przyczyny:**
1. DNS nie wskazuje jeszcze na właściwy IP (poczekaj dłużej)
2. Porty 80 i 443 są zamknięte w firewall
3. Let's Encrypt nie może zweryfikować domeny

**Rozwiązanie:**
```bash
# Sprawdź firewall:
sudo ufw status

# Sprawdź czy porty są otwarte:
sudo ufw status | grep -E "(80|443)"

# Jeśli nie - otwórz je:
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### Problem: Błąd SSL przy próbie wejścia na https://212.127.93.27

**Błąd:** `ERR_SSL_UNRECOGNIZED_NAME_ALERT` lub podobny błąd SSL

**Przyczyna:** 
Nie można uzyskać poprawnego certyfikatu SSL dla samego adresu IP. Certyfikaty SSL (w tym Let's Encrypt) są wydawane tylko dla domen, nie dla IP. Przeglądarki odrzucą połączenie HTTPS do IP, zanim Nginx będzie mógł wykonać przekierowanie.

**Rozwiązanie:**
1. **Użyj HTTP zamiast HTTPS:** `http://212.127.93.27` przekieruje na `https://sowa.ch`
2. **Wyłącz SSL w Redirect Host (jeśli jeszcze go masz włączony):**
   - Wejdź do NPM GUI: `http://212.127.93.27:81`
   - Przejdź do: **Hosts** → **Redirect Hosts** → Edytuj host dla `212.127.93.27`
   - W zakładce **SSL** wybierz: **None** (lub usuń certyfikat)
   - Zapisz

3. **Jeśli chcesz obsługiwać HTTPS do IP (niezalecane):**
   - Możesz użyć self-signed certyfikatu, ale przeglądarki nadal będą pokazywać ostrzeżenie
   - Nie ma sensu, bo przekierowanie działa tylko przez HTTP

**Zalecenie:** Użytkownicy powinni używać `http://212.127.93.27`, które automatycznie przekieruje na `https://sowa.ch` z prawidłowym certyfikatem SSL.

#### Rozwiązanie z Cloudflare Proxy (jeśli chcesz obsługiwać HTTPS do IP)

Jeśli chcesz, aby HTTPS do IP działało bez błędu SSL, możesz użyć Cloudflare Proxy:

1. **Utwórz subdomenę w Cloudflare DNS:**
   - Wejdź do panelu Cloudflare: https://dash.cloudflare.com
   - Wybierz domenę `sowa.ch`
   - Przejdź do **DNS** → **Records**
   - Dodaj nowy rekord:
     - **Typ:** `A`
     - **Nazwa:** `ip` (lub dowolna inna subdomena)
     - **Content:** `212.127.93.27`
     - **Proxy status:** ✅ **Proxied** (pomarańczowa chmurka) - **WAŻNE!**
     - **TTL:** Auto
   - Kliknij **Save**

2. **Skonfiguruj przekierowanie w NPM dla subdomeny:**
   - W NPM GUI: **Hosts** → **Redirect Hosts** → **Add Redirect Host**
   - **Domain Names:** `ip.sowa.ch` (lub nazwa którą wybrałeś)
   - **Forward Hostname/IP:** `sowa.ch`
   - **Forward Port:** `443`
   - **Forward Scheme:** `https`
   - **Redirect Type:** `Permanent (301)`
   - **Preserve Path:** ✅
   - Kliknij **Save**

3. **Skonfiguruj SSL w NPM dla subdomeny (opcjonalnie):**
   - W zakładce **SSL** wybierz: **Request a new SSL Certificate with Let's Encrypt**
   - Cloudflare Proxy zapewni, że certyfikat będzie działał

4. **Teraz użytkownicy mogą używać:**
   - `http://212.127.93.27` → przekieruje na `https://sowa.ch` ✅
   - `https://ip.sowa.ch` → przekieruje na `https://sowa.ch` z prawidłowym SSL przez Cloudflare ✅
   - `https://212.127.93.27` → nadal będzie błąd SSL (nie można tego obejść bezpośrednio dla IP)

⚠️ **Uwaga:** 
- **CNAME nie może wskazywać na IP** - musisz użyć rekordu typu **A**
- Cloudflare Proxy (pomarańczowa chmurka) obsługuje SSL i zapewni certyfikat dla subdomeny
- Jeśli wyłączysz proxy (szara chmurka), będziesz miał ten sam problem z SSL dla IP

### Problem: IP nadal pokazuje stronę NPM zamiast przekierowania

**Diagnoza:**
```bash
# Sprawdź aktualną konfigurację domyślnego hosta:
cat /srv/nginx-proxy-manager/data/nginx/default_host.conf

# Sprawdź logi NPM:
docker logs nginx-proxy-manager --tail 50

# Sprawdź czy Nginx załadował konfigurację:
docker exec nginx-proxy-manager nginx -t
```

**Rozwiązanie krok po kroku:**

1. **Sprawdź czy plik istnieje i ma właściwą zawartość:**
   ```bash
   sudo cat /srv/nginx-proxy-manager/data/nginx/default_host.conf
   ```
   
   Jeśli plik nie istnieje lub jest pusty, utwórz go:
   ```bash
   sudo mkdir -p /srv/nginx-proxy-manager/data/nginx/
   sudo nano /srv/nginx-proxy-manager/data/nginx/default_host.conf
   # Wklej konfigurację z Opcji C
   ```

2. **Upewnij się, że masz poprawne uprawnienia:**
   ```bash
   sudo chown -R 101:101 /srv/nginx-proxy-manager/data/nginx/
   ```

3. **Zrestartuj NPM i sprawdź błędy:**
   ```bash
   docker restart nginx-proxy-manager
   sleep 5
   docker logs nginx-proxy-manager --tail 20
   ```

4. **Jeśli nadal nie działa, sprawdź czy NPM nie nadpisuje konfiguracji:**
   ```bash
   # Sprawdź wszystkie pliki konfiguracyjne Nginx:
   ls -la /srv/nginx-proxy-manager/data/nginx/proxy_host/
   
   # Sprawdź czy jest jakiś catch-all proxy host:
   docker exec nginx-proxy-manager cat /data/nginx/proxy_host/*.conf | grep default_server
   ```

5. **Alternatywnie - użyj catch-all poprzez Proxy Host:**
   - Utwórz nowy Proxy Host w NPM GUI
   - W Domain Names: zostaw puste lub wpisz `_` (wildcard)
   - W Advanced → Custom Nginx Configuration dodaj: `return 301 https://sowa.ch$request_uri;`
   - Włącz opcję "Catch All" jeśli dostępna

## Struktura

```
Internet (http://212.127.93.27)
    ↓
NPM Container (port 80/443)
    ↓ sprawdza nagłówek Host
    ↓ jeśli pasuje do Proxy Host → forwarduje
    ↓
Landing Container (nazwa: landing, port 3000)
    ↓
Next.js Application
```

## Ważne uwagi

1. **Nazwa kontenera:** Używaj nazwy kontenera (`landing`), nie IP
2. **Sieć Docker:** Kontener landing musi być w sieci `nginx_proxy_manager_network`
3. **Port:** Landing działa na porcie 3000 (Next.js)
4. **DNS:** Dla SSL potrzebujesz działającej domeny z rekordem A wskazującym na IP serwera

## Przykładowa konfiguracja dla kilku domen

Możesz mieć wiele Proxy Hosts w NPM:

- `sowa.ch` → `landing:3000` (landing page)
- `npm.sowa.ch` → `host.docker.internal:81` (NPM admin)
- `portainer.sowa.ch` → `portainer:9000` (Portainer)
- `app.sowa.ch` → `app:8000` (Django app)

Każda domena może mieć swój własny certyfikat SSL i konfigurację.
