# TODO — serwer `daktylowy` (sowa.ch)

Utworzone: 2026-09-06. Kolejność = priorytet. Pełne uzasadnienie: `przeglad-serwera-daktylowy.md`.

Legenda: `[ ]` do zrobienia · `[~]` w trakcie · `[x]` zrobione · ⚠️ = ryzyko przerwania usług

---

## 🔴 DZIŚ — bezpieczeństwo + stabilność (ok. 1h)

### 1. Zamknąć panele admin przed publicznym internetem ✅ (2026-09-12)
Wszystkie na `*.sowa.ch` szły przez **Cloudflare proxy** (orange cloud) — nginx w NPM widział zawsze adres brzegowy Cloudflare, nie prawdziwy IP klienta, więc zwykła reguła `Allow 192.168.50.0/24` była martwa (nie mogła zadziałać nawet dla ruchu z LAN). Rozwiązanie: **Tailscale** zainstalowany i podłączony (`daktylowy` = `100.111.250.35`) + podział na dwie listy dostępu wg realnego ryzyka:
- [x] **Tailscale zainstalowany i połączony** (`tailscale status` → `daktylowy 100.111.250.35`), hostname `--ssh` włączony
- [x] Access List **`internal-panels`** (Satisfy All, auth `pawlo884`): reguły w kolejności `Allow 192.168.50.0/24` → `Allow 100.64.0.0/10` (zakres Tailscale) → `Deny all` — przypięta do najbardziej krytycznych: `portainer`, `pgadmin`, `minio`, `minio-api` (pełna kontrola Dockera / bazy / plików S3 — tu wymagane LAN lub Tailscale + hasło)
- [x] Access List **`password-only`** (Satisfy Any, samo hasło, bez ograniczenia IP) — przypięta do reszty paneli niższego ryzyka: `grafana`, `prometheus`, `qdrant`, `n8n`, `nc-dev`, `spy`, `asus`, `ip` (dashboardy/podgląd, nie kontrola)
- [x] Zostały bez Access List (publiczne): `sowa.ch`, `nc.sowa.ch`, `shop.sowa.ch`, `npm.sowa.ch`
- [x] `ej.sowa.ch` — host usunięty z NPM (decyzja: niepotrzebny)
- Zweryfikowane lokalnym curlem (SNI): `shop.sowa.ch`→200 (publiczny), `grafana.sowa.ch`→401 (prosi o hasło), `portainer.sowa.ch`/`pgadmin.sowa.ch`→403 (blokada przed hasłem, bo poza LAN/Tailscale)
- [x] **Split DNS w Tailscale skonfigurowany** (`sowa.ch` → `100.111.250.35`, nameserver: własny `dnsmasq` jako systemd service `dnsmasq-sowa.service`, config `/etc/dnsmasq-sowa.conf`, nasłuchuje tylko na `tailscale0`, bez forwardingu — nie jest to otwarty resolver) — plik `hosts` na klientach już niepotrzebny
- **Dwie dodatkowe pułapki znalezione i naprawione po drodze (zapisane, bo mogą wrócić przy kolejnych hostach):**
  1. **Tailscale robił własny SNAT** (`ts-postrouting` w iptables, mark `0x40000/0xff0000`) na ruchu przekazywanym do sieci Dockera — nginx widział bramę mostka zamiast prawdziwego IP klienta. Naprawa: `sudo tailscale set --snat-subnet-routes=false`.
  2. **IPv6 psuje to samo na nowo**: sieć dockerowa NPM jest czysto IPv4 (`172.24.0.0/16`), więc dla połączeń IPv6 (np. gdy Split DNS/hosts miał też rekord AAAA) Docker musi użyć wewnętrznego `docker-proxy`, który otwiera **nowe** połączenie do kontenera z adresu bramy mostka — znów gubiąc realny IP klienta. Naprawa: w `dnsmasq-sowa.conf` zwracać dla `sowa.ch` **tylko rekord A (IPv4)**, żadnego AAAA.

### 2. Utwardzić SSH ⚠️ ✅ (2026-09-12)
Klucz użytkownika `pawel` działa (10 wpisów w `authorized_keys`), root nie ma klucza.
- [x] Potwierdzone logowanie kluczem w osobnej sesji przed zmianą
- [x] `/etc/ssh/sshd_config.d/99-hardening.conf`:
  ```
  PasswordAuthentication no
  KbdInteractiveAuthentication no
  PermitRootLogin no
  ```
- [x] `sudo sshd -t && sudo systemctl restart ssh` — config poprawny, restart bez przerwania aktywnych sesji
- [x] Zweryfikowane nową sesją (klucz wchodzi, próba hasłem odrzucona od razu — `Permission denied (publickey)`)

### 3. Odzyskać ~20 GB na dysku ✅ (2026-09-12, częściowo — build cache już był mniejszy dzięki cotygodniowemu cleanupowi)
- [x] `docker builder prune -af` — odzyskane 4.84 GB
- [x] `docker image prune -af` — odzyskane 2.23 GB
- [x] `df -h /` — **71% → 66%** (42 GB → 49 GB wolnego), wszystkie 23 kontenery przeżyły bez przerwy

### 4. Dodać swap ✅ (zrobione przed tą sesją, zweryfikowane 2026-09-12)
- [x] 8 GB `/swapfile` aktywny (`swapon --show`), prawie niewykorzystany
- [x] Wpis w `/etc/fstab` (przeżyje reboot)
- [x] `vm.swappiness=10` aktywne (`/etc/sysctl.d/99-swap.conf`)

### 5. Ograniczyć obciążenie od Cursora 🟡 (częściowo, 2026-09-12)
Load spadł już samoistnie do ~1 (z 13–23) — nie ma już palącego problemu, ale zapobiegawczo dograne:
- [x] `files.watcherExclude` + `search.exclude` w `~/.cursor-server/data/User/settings.json`:
  `**/Recordings/**`, `/mnt/**`, `**/.venv/**`, `**/node_modules/**`, `**/.git/**`
  (**wymaga reload okna Cursora, żeby zadziałało**)
- [x] `.cursorignore` dodany w `/home/pawel` i `/opt/vps`
- [ ] Nadal 18 procesów cursor-server — jeśli masz otwarte niepotrzebne okna, zamknij ręcznie
- [ ] Opcjonalnie: `systemctl edit user@1000.service` → `[Service]` `CPUQuota=300%` (nie zrobione, load już niski, niska priorytetowość)

---

## 🟠 TEN TYDZIEŃ — infrastruktura

### 6. Reboot na nowy kernel ⚠️ ✅ (2026-09-12)
Zaległy od 2026-09-03 (`6.8.0-139`, `linux-base`).
- [x] `sudo apt update && sudo apt full-upgrade` — docker-ce 29.7→29.8, containerd, linux-firmware
- [x] `sudo reboot` (zerwało też sesję Claude Code — oczekiwane, ta sama maszyna)
- [x] Po restarcie: kernel `6.8.0-139-generic` ✅, 18/18 kontenerów wstało, k3s dalej usunięty, Tailscale/dnsmasq-sowa/SSH hardening/swap wszystko przetrwało, `shop`/`nc`/`pgadmin`/`grafana` przetestowane — zachowują się jak powinny

### 7. Przenieść dane z dysku root na 2 TB
Root 76%, `/mnt/data2tb` w 1%.
- [ ] Zatrzymać Docker: `sudo systemctl stop docker`
- [ ] `/etc/docker/daemon.json` → `{ "data-root": "/mnt/data2tb/docker" }`
- [ ] `sudo rsync -aP /var/lib/docker/ /mnt/data2tb/docker/`
- [ ] `sudo systemctl start docker` → zweryfikować `docker ps`, potem usunąć stare `/var/lib/docker`
- [ ] Przenieść `/srv/backups` → `/mnt/data2tb/backups` (zaktualizować ścieżki w `pg_backup_*.sh`)

### 8. Backupy off-site + test restore
Teraz: lokalnie, jeden dysk, retencja 7 dni, nietestowane, bez wolumenów.
- [ ] Zainstalować `restic` lub `rclone`
- [ ] Repo zdalne (inny host / Backblaze B2 / S3)
- [ ] Backupować: `/srv/backups/postgres` + wolumeny `n8n`, `qdrant`, `minio`, NPM `database.sqlite`, Portainer
- [ ] Wpis w crontab (codziennie po `pg_backup`)
- [ ] **Raz** przetestować pełny restore jednej bazy do kontenera testowego
- [ ] Wydłużyć retencję lokalną do 14–30 dni

### 9. Zdecydować: k3s ALBO Docker Compose dla `nc` ⚠️ ✅ (2026-09-12)
Web już był 0/0 replik w k3s od 16+ dni — realnie działał tylko przez Compose (`nc-web` healthy, `nc.sowa.ch` → `proxy_pass http://nc-web:8000` w NPM, zweryfikowane działające przed i po).
- [x] Decyzja: **Compose**, k3s usunięty
- [x] `sudo /usr/local/bin/k3s-uninstall.sh` — czysto, bez przestoju kontenerów Dockera → **+40 GB dysku (66%→38% zajęte, 49GB→89GB wolnego)**
- [x] Ingress w NPM już wskazywał na kontener (`nc-web:8000`), nic do zmiany

### 10. Zdecydować: Netdata ALBO Prometheus/Grafana ✅ (2026-09-12)
Dwa stacki, ~17% CPU non-stop, cAdvisor sam ~10%.
- [x] Decyzja: **Netdata zostaje**, stack `observability` zdjęty (`docker compose down` w `/home/pawel/stacks/observability`) — usunięte: `prometheus`, `grafana`, `cadvisor`, `node_exporter`, `postgres_exporter_nc` (23→18 kontenerów)
- [x] Wolumeny `observability_grafana-data` i `observability_prom-data` **zostawione** na dysku (nieusunięte), gdyby ktoś chciał wrócić do dashboardów
- ⚠️ Zanotowane: Grafana miała `admin/admin` jako hasło admina — zmienić od razu, jeśli stack kiedyś wróci

---

## 🟡 HIGIENA — bez pośpiechu

- [ ] Przypiąć wersje obrazów zamiast `:latest`: `n8n`, `minio`, `pgadmin4`, `nginx-proxy-manager`, `qdrant`, `portainer-ce`
- [ ] Ujednolicić Postgres → wszędzie `18.1-alpine`
- [ ] `docker_cleanup.sh`: dopisać `docker builder prune -f --filter until=168h` + `docker image prune -af --filter until=168h`
- [ ] Uporządkować config: aktywne `/home/pawel/stacks/`; usunąć puste `/opt/vps/stacks/`, nieużywane `/home/pawel/projects/nc/`
- [ ] Zsynchronizować rzeczywisty stan do repo Ansible `/opt/vps` (są niezacommitowane zmiany, stary HEAD)
- [ ] `/etc/apt/apt.conf.d/50unattended-upgrades`: `Unattended-Upgrade::Automatic-Reboot "true"` + `Automatic-Reboot-Time "04:30"`
- [ ] Alerty (Netdata/Grafana): dysk >85%, brak świeżego backupu >26h, load>8 przez 15 min, cert TLS <14 dni
- [ ] Redis: przenieść z `172.17.0.1:6379` na dedykowaną sieć docker zamiast docker0
- [ ] `nc-celery-*`: sprawdzić czemu restartowały się (uptime 3h); rozważyć `healthcheck` zamiast `sleep 20`
- [ ] `timedatectl` — sprawdzić zegar/RTC (pliki PrestaShop z mtime 2027)
- [ ] Wyłączyć nieużywane: `sudo systemctl disable --now bluetooth ModemManager` (jeśli nie do nagrywania Soundcore)
- [ ] Naprawić lub wyłączyć `bt-record-healthcheck.service` (faił w logach)
- [ ] Rozważyć `PermitRootLogin no` już zrobione w kroku 2 — potwierdzić

---

## 💡 PLAN NA PRZYSZŁOŚĆ (nie wdrażać teraz)

### 11. Herdr + Hermes Agent + Notion (workflow: Telegram → agent → Notion jako pamięć)
Zapisane 2026-09-12, świadomie odłożone do czasu domknięcia sekcji 🔴/🟠 powyżej — Hermes przez Telegram to kolejny zdalny kanał z dostępem do plików/dev environment, nie ma sensu dokładać go, zanim panele i SSH nie są zamknięte.
- **Herdr** — [herdrdev/herdr](https://github.com/herdrdev/herdr), terminal multiplexer dla sesji agentów (Claude Code/Codex), instalacja: `curl -fsSL https://herdr.dev/install.sh | sh`
- **Hermes Agent** — [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent), self-hosted agent AI z gatewayem do Telegram/Discord/Slack/itd., config `~/.hermes/config.yaml`; podłączenie do herdr: `herdr integration install hermes`
- **Notion** — jako pamięć/baza ticketów, research, brainstormów, raportów postępu (po stronie Hermesa)
- Do wdrożenia potrzebne: token bota Telegram (BotFather), integration token Notion — **żaden jeszcze nie założony** (stan na 2026-09-12)
- [ ] Dokończyć najpierw punkty 1-10 wyżej (panele + SSH + reboot + backupy)
- [ ] Założyć token Telegram bota (BotFather) i integration token Notion
- [ ] Zainstalować herdr, potem hermes-agent, spiąć `herdr integration install hermes`
- [ ] Rozważyć izolację (osobny user systemowy / kontener) skoro to zdalny kanał sterowania

---

## ✅ Działa dobrze — nie ruszać
UFW + fail2ban · TLS/Let's Encrypt (do 28.10) · codzienne backupy PG · stack observability przypięty do wersji · Redis z hasłem + `CONFIG` zdisablowane · unattended-upgrades aktywne · k3s na LAN IP (nie 0.0.0.0) · healthchecki baz
