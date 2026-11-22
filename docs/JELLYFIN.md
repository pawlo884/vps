# Jellyfin — filmy i seriale zdalnie

Rola `ansible/roles/jellyfin`, włączana przez `jellyfin_install: true` (prod: `group_vars/all.yml`).

## Dostęp: publicznie, ale DNS-only (szara chmurka)

Jellyfin ma działać też na TV bez Tailscale, więc jest wystawiony publicznie przez NPM.
Rekord w Cloudflare **musi być DNS-only (szara chmurka)**: streaming wideo przez proxy CF
(pomarańczowa chmurka) łamie ich ToS i bywa dławiony. Ruch idzie wtedy prosto na
`212.127.93.27` → NPM (443) → `jellyfin:8096`.

Konsekwencje i zabezpieczenia:
- Widać domowe IP w DNS dla `jellyfin.sowa.ch` (inne hosty nadal za proxy CF).
- Logowanie Jellyfin jest dostępne z internetu → **silne hasła**, bez kont bez hasła,
  wyłączone „Show on login screen”/szybkie logowanie dla kont.
- **fail2ban** (jail `jellyfin`): 5 nieudanych logowań w 10 min → ban na 6h. Ban idzie do
  łańcucha `DOCKER-USER`, bo ruch do NPM (port Dockera) omija `INPUT`, gdzie działa `ufw`.
- Jellyfin dostaje `KnownProxies` = podsieć sieci NPM, żeby w logach widział prawdziwy IP
  klienta (z `X-Forwarded-For`), a nie IP kontenera NPM.
- Z LAN/Tailscale dalej działa ta sama nazwa (Split DNS → `100.111.250.35`).

## Co robi rola

- Kontener `jellyfin` (obraz przypięty w `defaults/main.yml`) w sieci `nginx_proxy_manager_network`,
  port 8096 tylko na `127.0.0.1` (awaryjnie: `ssh -L 8096:127.0.0.1:8096 pawel@HOST`).
- Działa jako użytkownik `pawel` (UID/GID z hosta), więc pliki wrzucone przez `pawel` są od razu widoczne.
- Katalogi na dysku 2TB:
  - `/mnt/data2tb/jellyfin/config` — konfiguracja, baza, metadane
  - `/mnt/data2tb/jellyfin/cache` — cache transkodowania
  - `/mnt/data2tb/media/{filmy,seriale}` — biblioteka, w kontenerze `/media` (read-only)
- Jeśli istnieje `/dev/dri/renderD128` (Intel iGPU), podłącza go + grupy `render`/`video`
  pod sprzętowe transkodowanie.

## Kroki ręczne po deployu

1. **Cloudflare → DNS**: `A jellyfin → 212.127.93.27`, **Proxy status: DNS only** (szara chmurka).
2. **NPM → Proxy Hosts → Add**: `jellyfin.sowa.ch` → `http` / `jellyfin` / `8096`,
   *Websockets Support* ON, *Block Common Exploits* ON, **bez Access List**.
   SSL: *Request a new SSL Certificate* (Let's Encrypt, HTTP challenge przejdzie, bo rekord jest publiczny),
   *Force SSL* ON, *HTTP/2* ON. Advanced (opcjonalnie, duże pliki/seek): `proxy_buffering off;`
3. Otwórz `https://jellyfin.sowa.ch` → kreator: konto admina (silne hasło), biblioteki
   `Filmy` → `/media/filmy`, `Seriale` → `/media/seriale`.
4. **Uruchom rolę drugi raz** (`DEPLOY_TAGS=jellyfin`): po pierwszym starcie istnieją już
   `network.xml` i logi, więc rola ustawi `KnownProxies` (restart Jellyfin) i jail fail2ban.
   Sprawdzenie: `sudo fail2ban-client status jellyfin`.
5. Dashboard → Playback → Transcoding: *Intel QuickSync (QSV)* (albo VAAPI), urządzenie `/dev/dri/renderD128`.
6. Wrzucanie plików: `rsync -avP film.mkv pawel@daktylowy:/mnt/data2tb/media/filmy/`
   (po Tailscale), potem w Jellyfin *Scan library* (albo poczekaj na automatyczny skan).

## Klienci

Aplikacja Jellyfin (Android/iOS/Android TV/webOS/Tizen) lub przeglądarka, serwer:
`https://jellyfin.sowa.ch` — działa z dowolnej sieci, także na TV bez Tailscale.

## Kopia zapasowa

Warto backupować `/mnt/data2tb/jellyfin/config` (użytkownicy, postęp oglądania, metadane).
Biblioteka mediów nie jest backupowana przez tę rolę.
