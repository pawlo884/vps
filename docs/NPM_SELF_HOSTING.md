# Wystawienie NPM przez npm.sowa.ch

## Jak działa NPM jako reverse proxy

NPM działa w następujący sposób:

1. **Porty publiczne (dostępne z internetu):**
   - Port 80 (HTTP) - NPM nasłuchuje na wszystkich żądaniach HTTP
   - Port 443 (HTTPS) - NPM nasłuchuje na wszystkich żądaniach HTTPS

2. **Port lokalny (tylko z hosta):**
   - Port 81 (Admin Interface) - interfejs administracyjny NPM

3. **Routing przez NPM:**
   - NPM sprawdza nagłówek `Host` w żądaniu HTTP/HTTPS
   - Jeśli domena pasuje do skonfigurowanego Proxy Host → przekierowuje na odpowiedni backend
   - Jeśli nie pasuje → pokazuje domyślną stronę lub błąd 404

## Konfiguracja npm.sowa.ch

### Krok 1: Ustaw DNS

W panelu DNS ustaw rekord A:
```
npm.sowa.ch  →  IP_TWOJEGO_SERWERA
```

Możesz sprawdzić IP serwera:
```bash
hostname -I
```

### Krok 2: Skonfiguruj Proxy Host w NPM

1. **Wejdź do NPM:**
   - Otwórz: `http://IP_SERWERA:81` lub `http://localhost:81`
   - Zaloguj się

2. **Dodaj Proxy Host:**
   - Kliknij: **Hosts** → **Proxy Hosts** → **Add Proxy Host**

3. **Ustawienia Details:**
   - **Domain Names:** `npm.sowa.ch`
   - **Scheme:** `http`
   - **Forward Hostname/IP:** `host.docker.internal` ⚠️ WAŻNE!
   - **Forward Port:** `81`
   - ✅ **Block Common Exploits**
   - ✅ **Websockets Support** (jeśli potrzebne)

4. **Ustawienia SSL (ważne!):**
   - Kliknij zakładkę **SSL**
   - Wybierz: **Request a new SSL Certificate with Let's Encrypt**
   - ✅ **I Agree to the Let's Encrypt Terms of Service**
   - ✅ **Force SSL** (przekieruj HTTP na HTTPS)
   - ✅ **HTTP/2 Support**
   - ✅ **HSTS Enabled** (opcjonalnie, ale zalecane)
   - Kliknij **Save**

5. **Poczekaj na certyfikat:**
   - Let's Encrypt automatycznie wygeneruje certyfikat (może zająć 1-2 minuty)
   - Sprawdź status w **SSL Certificates**

### Krok 3: Sprawdź działanie

Po skonfigurowaniu:
```bash
# Z internetu (jeśli DNS działa):
curl -I https://npm.sowa.ch

# Powinno zwrócić HTTP 200 lub 302 (redirect)
```

## Jak to działa technicznie

```
┌─────────────────────────────────────────────────────────┐
│  Internet (Przeglądarka)                                │
│  npm.sowa.ch (DNS → IP serwera)                        │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│  Serwer: Port 80/443 (NPM Container)                   │
│  ┌───────────────────────────────────────────────┐     │
│  │ NPM sprawdza nagłówek Host: npm.sowa.ch      │     │
│  │ Znajduje Proxy Host dla npm.sowa.ch          │     │
│  │ Przekierowuje na: host.docker.internal:81    │     │
│  └──────────────────┬────────────────────────────┘     │
└─────────────────────┼───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│  host.docker.internal:81 (NPM Admin Interface)         │
│  Interfejs administracyjny NPM                         │
└─────────────────────────────────────────────────────────┘
```

## Dlaczego `host.docker.internal`?

- NPM działa w kontenerze Docker
- Port 81 jest wystawiony na hoście jako `0.0.0.0:81`
- `host.docker.internal` to specjalny hostname, który Docker rozpoznaje jako gateway do hosta
- To pozwala kontenerowi NPM połączyć się z portem 81 na hoście (czyli samym sobą)

## Bezpieczeństwo

✅ **Zalecane:**
- Użyj HTTPS (SSL certificate z Let's Encrypt)
- Włącz Force SSL
- Ustaw silne hasło w NPM
- Rozważ ograniczenie dostępu do portu 81 przez firewall (tylko z lokalnego hosta)

## Rozwiązywanie problemów

### Problem: "Bad Gateway" lub 502
- Sprawdź czy `host.docker.internal` działa: `docker exec nginx-proxy-manager ping -c 1 host.docker.internal`
- Sprawdź czy port 81 jest dostępny: `curl http://host.docker.internal:81/` z wnętrza kontenera

### Problem: Certyfikat SSL nie działa
- Sprawdź czy DNS wskazuje na właściwy IP
- Sprawdź logi w NPM: `docker logs nginx-proxy-manager`
- Upewnij się, że porty 80 i 443 są otwarte w firewall

### Problem: NPM nie działa po restarcie
- Sprawdź czy kontener się uruchomił: `docker ps | grep nginx-proxy-manager`
- Sprawdź logi: `docker logs nginx-proxy-manager`

## Ważne uwagi

⚠️ **Nie konfiguruj npm.sowa.ch na `localhost` lub `127.0.0.1`!**
- Z wnętrza kontenera `localhost` oznacza kontener, nie host
- Użyj `host.docker.internal` lub IP hosta z perspektywy kontenera

✅ **Po skonfigurowaniu npm.sowa.ch:**
- Możesz nadal używać `http://IP:81` lokalnie
- npm.sowa.ch będzie dostępny przez HTTPS z internetu
- Wszystkie inne proxy hosts w NPM działają normalnie
