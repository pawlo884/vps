# Automatyczne budzenie urządzenia przez Wake on LAN przy próbie dostępu

## Problem

Urządzenie `192.168.50.63` z aplikacjami (porty 8090, 8501) uśpia się automatycznie. Gdy użytkownik próbuje połączyć się przez NPM, otrzymuje błąd 502 (Bad Gateway), bo urządzenie śpi.

## Rozwiązanie

Usługa systemd **nasłuchuje logów NPM w czasie rzeczywistym** (`docker logs -f`). Gdy w logu pojawi się błąd 502/Bad Gateway dla `192.168.50.63`, wysyła pakiet Wake on LAN. **Bez pollingu** – reakcja tylko na żądanie (gdy ktoś wejdzie na stronę i dostanie 502).

## Migracja z wersji z timerem (co 10 s)

Jeśli wcześniej używałeś timera:

```bash
sudo systemctl stop wol-auto-wake.timer
sudo systemctl disable wol-auto-wake.timer
# Skopiuj nowy skrypt i service (Krok 4 poniżej), potem:
sudo systemctl daemon-reload
sudo systemctl enable wol-auto-wake.service
sudo systemctl start wol-auto-wake.service
```

## Instalacja

### Krok 1: Zainstaluj wakeonlan

```bash
sudo apt-get update
sudo apt-get install -y wakeonlan
```

### Krok 2: Znajdź MAC adres urządzenia

```bash
# Opcja A: Przez ARP (jeśli urządzenie było aktywne)
arp -a | grep 192.168.50.63

# Opcja B: Wymuś ping i sprawdź ARP
ping -c 1 192.168.50.63
arp -n 192.168.50.63 | awk '{print $3}'

# Opcja C: W routerze sprawdź listę urządzeń DHCP
```

**Zapisz MAC adres** (format: `AA:BB:CC:DD:EE:FF` lub `aa:bb:cc:dd:ee:ff`)

### Krok 3: Skonfiguruj skrypt

```bash
# Edytuj skrypt i zmień MAC adres
sudo nano /opt/vps/scripts/wol-auto-wake.sh
```

Znajdź linię:
```bash
TARGET_MAC="AA:BB:CC:DD:EE:FF"  # ⚠️ ZMIEŃ NA PRAWIDŁOWY MAC!
```

I zmień na prawidłowy MAC adres, np:
```bash
TARGET_MAC="12:34:56:78:9A:BC"
```

**Opcjonalnie:** Jeśli Twoje aplikacje są na innych portach, zmień:
```bash
PORTS=(8090 8501)  # Zmień na swoje porty
```

### Krok 4: Skopiuj pliki do systemowych lokalizacji

```bash
# Skopiuj skrypt
sudo cp /opt/vps/scripts/wol-auto-wake.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/wol-auto-wake.sh

# Skopiuj jednostkę systemd (timer nie jest używany – budzenie na żądanie)
sudo cp /opt/vps/scripts/wol-auto-wake.service /etc/systemd/system/
```

### Krok 5: Utwórz katalog logów (jeśli nie istnieje)

```bash
sudo touch /var/log/wol-auto-wake.log
sudo chmod 644 /var/log/wol-auto-wake.log
```

### Krok 6: Załaduj i uruchom usługę

```bash
# Przeładuj systemd
sudo systemctl daemon-reload

# Włącz i uruchom usługę (działa w tle, nasłuchuje logów NPM)
sudo systemctl enable wol-auto-wake.service
sudo systemctl start wol-auto-wake.service

# Sprawdź status
sudo systemctl status wol-auto-wake.service
```

### Krok 7: Sprawdź działanie

```bash
# Sprawdź status usługi
sudo systemctl status wol-auto-wake.service

# Logi na żywo (journal)
sudo journalctl -u wol-auto-wake.service -f

# Logi skryptu (plik)
sudo tail -f /var/log/wol-auto-wake.log
```

## Jak to działa

1. **Usługa działa w tle** i uruchamia `docker logs -f` na kontenerze NPM (tylko nowe linie).
2. **Gdy w logu pojawi się linia** z 502/Bad Gateway/Connection refused **oraz** adresem `192.168.50.63`:
   - Sprawdza, czy urządzenie rzeczywiście nie odpowiada (test TCP na portach 8090, 8501)
   - Jeśli nie odpowiada → wysyła pakiet WoL
   - Czeka 30 sekund na obudzenie
3. **Cooldown 90 s** – nie budzi ponownie w ciągu 90 sekund od ostatniego WoL.
4. **Bez pollingu** – zero sprawdzeń co X sekund; reakcja tylko gdy NPM zaloguje 502 (czyli gdy ktoś wejdzie na stronę i dostanie błąd).

## Konfiguracja NPM - zwiększ timeouty

⚠️ **UWAGA:** Jeśli pojawia się błąd "handshake error", użyj poprawnej konfiguracji poniżej.

W NPM GUI dla Proxy Host dodaj w **Advanced → Custom Nginx Configuration**:

```nginx
# Zwiększone timeouty dla urządzenia które może się uśpiać
# WAŻNE: Te ustawienia dodają się do domyślnej konfiguracji NPM
proxy_connect_timeout 60s;
proxy_send_timeout 60s;
proxy_read_timeout 60s;

# Dodatkowe ustawienia dla stabilności połączenia
proxy_http_version 1.1;
proxy_buffering off;
proxy_request_buffering off;
```

**Jeśli nadal występuje błąd handshake**, użyj mniejszych timeoutów:

```nginx
# Minimalna konfiguracja - tylko timeouty
proxy_connect_timeout 30s;
proxy_send_timeout 30s;
proxy_read_timeout 30s;
```

**Lub całkowicie usuń Custom Nginx Configuration** - skrypt WoL i tak zadziała automatycznie przy 502, więc zwiększone timeouty nie są absolutnie wymagane.

**Alternatywnie** - jeśli potrzebujesz dłuższych timeoutów, dodaj tylko `proxy_connect_timeout`:

```nginx
# Tylko timeout połączenia (najbezpieczniejsze)
proxy_connect_timeout 45s;
```

To daje czas na obudzenie urządzenia (30-60 sekund) zanim NPM zwróci błąd 502, który wywoła automatyczne WoL.

## Testowanie

### Test 1: Sprawdź czy usługa działa

```bash
# Sprawdź status usługi
systemctl status wol-auto-wake.service

# Powinna być aktywna (active/running) i nasłuchiwać logów
```

### Test 2: Symuluj błąd 502

1. Upewnij się że urządzenie `192.168.50.63` jest uśpione
2. Spróbuj wejść na domenę przez NPM (powinien być 502)
3. W ciągu chwili (reakcja na log 502)
4. Sprawdź logi:
   ```bash
   sudo tail -f /var/log/wol-auto-wake.log
   ```
5. Sprawdź czy urządzenie się obudziło:
   ```bash
   curl -I http://192.168.50.63:8090
   ```

### Test 3: Test WoL ręcznie

```bash
# Wyslij WoL ręcznie (zamień na prawidłowy MAC)
wakeonlan AA:BB:CC:DD:EE:FF

# Lub przez etherwake
INTERFACE=$(ip route | grep -oP 'dev \K\w+' | head -1)
sudo etherwake -i "$INTERFACE" AA:BB:CC:DD:EE:FF
```

## Rozwiązywanie problemów

### Problem: Usługa nie uruchamia się

```bash
# Sprawdź status
sudo systemctl status wol-auto-wake.service

# Sprawdź czy jest włączona
sudo systemctl is-enabled wol-auto-wake.service

# Przeładuj systemd i włącz ponownie
sudo systemctl daemon-reload
sudo systemctl enable wol-auto-wake.service
sudo systemctl start wol-auto-wake.service
```

### Problem: WoL nie działa

```bash
# Sprawdź czy wakeonlan jest zainstalowany
which wakeonlan

# Test WoL ręcznie
wakeonlan YOUR_MAC_ADDRESS

# Sprawdź logi
sudo journalctl -u wol-auto-wake.service -n 50
```

**Uwaga:** Wake on LAN wymaga:
- Włączonego WoL w BIOS urządzenia
- Włączonego WoL w ustawieniach sieciowych urządzenia
- Urządzenie musi być podłączone kablem Ethernet (WoL przez WiFi często nie działa)

### Problem: Urządzenie nie budzi się

1. **Sprawdź MAC adres:**
   ```bash
   # Czy MAC w skrypcie jest prawidłowy?
   grep TARGET_MAC /usr/local/bin/wol-auto-wake.sh
   ```

2. **Sprawdź logi:**
   ```bash
   sudo tail -50 /var/log/wol-auto-wake.log
   ```

3. **Sprawdź czy urządzenie wspiera WoL:**
   - BIOS → Wake on LAN → Enabled
   - Windows: Device Manager → Network Adapter → Power Management → "Allow this device to wake the computer"
   - Linux: `ethtool` → `Wake-on: g`

4. **Test WoL z innego urządzenia** w sieci lokalnej

### Problem: Skrypt budzi urządzenie za często

Sprawdź lock file:
```bash
ls -la /tmp/wol-wake.lock
cat /tmp/wol-last-wake
```

Lock zapobiega budzeniu w ciągu 90 sekund od ostatniego budzenia.

## Deinstalacja

```bash
# Zatrzymaj i wyłącz usługę
sudo systemctl stop wol-auto-wake.service
sudo systemctl disable wol-auto-wake.service

# Usuń plik systemd
sudo rm /etc/systemd/system/wol-auto-wake.service

# Przeładuj systemd
sudo systemctl daemon-reload

# Opcjonalnie usuń skrypt i logi
sudo rm /usr/local/bin/wol-auto-wake.sh
sudo rm /var/log/wol-auto-wake.log
```

## Ważne uwagi

⚠️ **Wake on LAN działa tylko:**
- W sieci lokalnej (LAN)
- Przez Ethernet (nie WiFi, chyba że router wspiera Wake on WLAN)
- Gdy urządzenie jest wyłączone, ale zasilanie jest włączone (nie całkowicie odłączone)

✅ **To rozwiązanie:**
- Automatycznie budzi urządzenie gdy ktoś próbuje połączyć się przez NPM
- Unika wielokrotnego budzenia (lock file)
- Loguje wszystkie operacje do `/var/log/wol-auto-wake.log`
- Nie przeszkadza normalnemu uśpianiu urządzenia (budzi tylko gdy jest potrzebne)

## Przykładowy przepływ

1. **Użytkownik wchodzi na domenę** → NPM próbuje połączyć z `192.168.50.63:8090`
2. **Urządzenie śpi** → NPM zwraca 502 Bad Gateway i zapisuje to w logu
3. **Usługa czyta log w czasie rzeczywistym** → Wykrywa linię z 502 dla `192.168.50.63`
4. **Skrypt sprawdza urządzenie** → Nie odpowiada na porcie 8090 ani 8501
5. **Skrypt wysyła WoL** → Pakiet magic packet wysłany do MAC
6. **Urządzenie się budzi** → Boot systemu + uruchomienie Docker/konternerów (30-60 sekund)
7. **Użytkownik odświeża stronę** → NPM łączy się → Aplikacja działa ✅
