# Rozwiązywanie problemu z qdrant.sowa.ch i Cloudflare

## Problem: DNS_PROBE_FINISHED_NXDOMAIN lub 404 przez Cloudflare

### Objawy:
- `qdrant.sowa.ch` zwraca błąd "DNS_PROBE_FINISHED_NXDOMAIN" w przeglądarce
- Cloudflare zwraca HTTP/2 404 dla qdrant.sowa.ch
- Qdrant działa lokalnie (curl z kontenera NPM zwraca 200 OK)

### Przyczyna:
DNS dla `qdrant.sowa.ch` wskazuje na Cloudflare IP (172.67.188.1, 104.21.7.202), ale:
- Cloudflare proxy może nie być poprawnie skonfigurowane
- Albo DNS record w Cloudflare wskazuje na niewłaściwy IP serwera

## Rozwiązanie

### Opcja 1: Wyłącz Cloudflare Proxy (zalecane dla serwisów wewnętrznych)

1. **Wejdź do panelu Cloudflare:**
   - Zaloguj się do https://dash.cloudflare.com
   - Wybierz domenę `sowa.ch`
   - Przejdź do **DNS** → **Records**

2. **Znajdź rekord dla qdrant.sowa.ch:**
   - Znajdź rekord A lub CNAME dla `qdrant`
   - Kliknij pomarańczową chmurkę (cloud) obok rekordu
   - Zmień na **szarą chmurkę** (DNS only) - to wyłączy proxy
   - Zapisz zmiany

3. **Upewnij się, że rekord wskazuje na właściwy IP:**
   - Rekord A powinien wskazywać na IP serwera: `192.168.50.31` (lub publiczne IP serwera)
   - Jeśli używasz CNAME, powinien wskazywać na domenę która ma właściwy A record

### Opcja 2: Popraw konfigurację Cloudflare Proxy

Jeśli chcesz używać Cloudflare proxy (pomarańczowa chmurka):

1. **Upewnij się, że IP serwera jest poprawny:**
   - W Cloudflare DNS: Rekord A dla `qdrant` → powinien wskazywać na **publiczne IP** serwera (nie lokalne 192.168.x.x)
   
2. **Wyłącz Cloudflare Proxy dla portów niestandardowych:**
   - Cloudflare proxy obsługuje tylko porty 80 i 443
   - Qdrant działa na porcie 6333 wewnętrznie, ale przez NPM jest dostępny na 80/443
   - Upewnij się, że Cloudflare przekierowuje na porty 80/443 serwera

3. **Sprawdź ustawienia SSL/TLS w Cloudflare:**
   - Ustaw SSL/TLS mode na **Full** lub **Full (strict)**
   - Nie używaj **Flexible** (to może powodować problemy)

### Opcja 3: Użyj bezpośredniego dostępu (tylko lokalnie)

Jeśli qdrant.sowa.ch ma być dostępny tylko lokalnie:
- Wyłącz Cloudflare proxy (szara chmurka)
- Ustaw rekord A na lokalne IP serwera
- Dodaj do `/etc/hosts` na lokalnym komputerze:
  ```
  192.168.50.31 qdrant.sowa.ch
  ```

## Weryfikacja konfiguracji

### Sprawdź czy Qdrant działa lokalnie:
```bash
# Z kontenera NPM:
docker exec nginx-proxy-manager curl -s http://qdrant:6333/ | python3 -m json.tool

# Z hosta:
curl -H "Host: qdrant.sowa.ch" http://localhost/ | python3 -m json.tool
```

### Sprawdź DNS:
```bash
dig +short qdrant.sowa.ch
# Powinno zwracać IP serwera (nie Cloudflare IP)
```

### Sprawdź czy NPM obsługuje qdrant.sowa.ch:
```bash
curl -H "Host: qdrant.sowa.ch" https://IP_SERWERA/ -k
# Powinno zwracać JSON z informacjami o Qdrant
```

## Aktualna konfiguracja

**Qdrant:**
- Kontener: `qdrant` (healthy)
- Port wewnętrzny: 6333 (HTTP), 6334 (gRPC)
- Port zewnętrzny: 6333, 6334 (dostępne bezpośrednio na hoście)
- Sieć: `nginx_proxy_manager_network` ✅

**NPM Proxy Host dla qdrant.sowa.ch:**
- Domain: `qdrant.sowa.ch` ✅
- Forward to: `qdrant:6333` ✅
- SSL Certificate: npm-38 (Let's Encrypt) ✅
- Force SSL: Enabled ✅

**Problem:** DNS wskazuje na Cloudflare IP zamiast na IP serwera, lub Cloudflare proxy nie działa poprawnie.

## Dostęp do interfejsu webowego Qdrant

**Ważne:** Qdrant ma interfejs webowy pod `/dashboard`, nie na głównej ścieżce `/`!

- ✅ **Interfejs webowy (panel logowania):** `https://qdrant.sowa.ch/dashboard`
- ✅ **API endpoint:** `https://qdrant.sowa.ch/` (zwraca JSON)

Jeśli chcesz, aby `/` automatycznie przekierowywało na `/dashboard`, możesz:

### Opcja A: Użyj `/dashboard` bezpośrednio (najprostsze)
Po prostu wejdź na: `https://qdrant.sowa.ch/dashboard`

### Opcja B: Dodaj przekierowanie w NPM GUI (opcjonalnie)

1. **Wejdź do NPM:** `http://localhost:81` lub `http://npm.sowa.ch`
2. **Otwórz konfigurację:** Proxy Hosts → `qdrant.sowa.ch` → Edit
3. **Przejdź do zakładki "Advanced"**
4. **W sekcji "Custom Nginx Configuration"** dodaj:
   ```nginx
   # Przekieruj główną ścieżkę na /dashboard
   location = / {
       return 301 /dashboard;
   }
   ```
5. **Zapisz** konfigurację

⚠️ **Uwaga:** To przekierowanie spowoduje, że `/` zawsze przekieruje na `/dashboard`. Jeśli potrzebujesz API na `/`, użyj bezpośrednio `/dashboard` zamiast przekierowania.

## Rekomendacja

**Najprostsze rozwiązanie:**
1. Używaj `https://qdrant.sowa.ch/dashboard` do interfejsu webowego
2. Używaj `https://qdrant.sowa.ch/` do API (zwraca JSON)
3. Jeśli chcesz przekierowanie, dodaj je w NPM GUI (Advanced → Custom Nginx Configuration)

**Dla DNS/Cloudflare:**
1. W Cloudflare DNS wyłącz proxy dla qdrant.sowa.ch (szara chmurka) - opcjonalnie
2. Ustaw rekord A: `qdrant` → `192.168.50.31` (lub publiczne IP serwera)
3. Poczekaj 1-2 minuty na propagację DNS
4. Sprawdź działanie: `curl https://qdrant.sowa.ch/dashboard`

**Alternatywnie** (jeśli używasz Cloudflare proxy):
- Ustaw rekord A na **publiczne IP** serwera (nie lokalne 192.168.x.x)
- Ustaw SSL/TLS mode na **Full (strict)**
- Upewnij się, że porty 80 i 443 są otwarte na firewall
