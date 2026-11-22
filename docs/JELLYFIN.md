# Jellyfin — filmy i seriale zdalnie

Rola `ansible/roles/jellyfin`, włączana przez `jellyfin_install: true` (prod: `group_vars/all.yml`).

## Dlaczego przez Tailscale, a nie publicznie przez Cloudflare

Ruch `*.sowa.ch` idzie przez Cloudflare proxy (orange cloud). Streaming wideo przez
proxy CF na darmowym planie łamie ich ToS (konto/strefa może zostać ograniczona) i bywa
dławiony. Dlatego Jellyfin jest dostępny **tylko z LAN i Tailscale**:

- Split DNS w Tailscale już rozwiązuje `*.sowa.ch` → `100.111.250.35`, więc
  `jellyfin.sowa.ch` z telefonu/laptopa w Tailscale trafia prosto do NPM, z pominięciem Cloudflare.
- W Cloudflare **nie dodajemy** rekordu `jellyfin` (albo co najwyżej szary/DNS-only — nie zalecane).

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

1. **NPM → Access Lists → Add**: `tailscale-only`, *Satisfy Any*, **bez** użytkowników/hasła,
   reguły: `Allow 192.168.50.0/24`, `Allow 100.64.0.0/10`, `Deny all`.
   (Nie używaj `internal-panels` — basic auth psuje aplikacje Jellyfin na TV/telefonie;
   Jellyfin ma własne logowanie.)
2. **NPM → Proxy Hosts → Add**: `jellyfin.sowa.ch` → `http` / `jellyfin` / `8096`,
   *Websockets Support* ON, *Block Common Exploits* ON, Access List `tailscale-only`.
   SSL: bez publicznego rekordu DNS HTTP challenge nie przejdzie — użyj **DNS Challenge
   (Cloudflare API token)** albo istniejącego certyfikatu wildcard `*.sowa.ch`.
   Advanced (opcjonalnie, duże pliki/seek): `proxy_buffering off;`
3. Otwórz `https://jellyfin.sowa.ch` (z Tailscale) → kreator: konto admina, biblioteki
   `Filmy` → `/media/filmy`, `Seriale` → `/media/seriale`.
4. Dashboard → Playback → Transcoding: *Intel QuickSync (QSV)* (albo VAAPI), urządzenie `/dev/dri/renderD128`.
5. Wrzucanie plików: `rsync -avP film.mkv pawel@daktylowy:/mnt/data2tb/media/filmy/`
   (po Tailscale), potem w Jellyfin *Scan library* (albo poczekaj na automatyczny skan).

## Klienci

Aplikacja Jellyfin (Android/iOS/Android TV/webOS/Tizen) lub przeglądarka, serwer:
`https://jellyfin.sowa.ch`. Urządzenie musi być w Tailscale (na TV bez Tailscale — tylko w LAN).

## Kopia zapasowa

Warto backupować `/mnt/data2tb/jellyfin/config` (użytkownicy, postęp oglądania, metadane).
Biblioteka mediów nie jest backupowana przez tę rolę.
