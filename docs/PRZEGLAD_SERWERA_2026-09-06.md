# Przegląd serwera `daktylowy` (sowa.ch) — 2026-09-06

Maszyna fizyczna (nie cloud VPS): HP ProDesk, Ubuntu 24.04.4, 6 rdzeni / 31 GB RAM,
LAN 192.168.50.31, domena `*.sowa.ch`. WiFi + Bluetooth + Wake-on-LAN → to domowy/biurowy serwer.
Uptime 16 dni.

---

## 1. Co na nim jest

### Wejście / sieć
- **nginx-proxy-manager** — jedyne co słucha publicznie (80/443), ~17 proxy hostów `*.sowa.ch`
- Certy Let's Encrypt OK (ważne do 28.10.2026)
- UFW aktywne (default deny in), fail2ban (4 jaile, 57 IP zbanowanych teraz / 265 łącznie)

### Orkiestracja — **dwie równolegle**
- **k3s** (single-node, 54 dni) — namespace `nc-prod`: `nc-web` 3 repliki, ingress `nc.sowa.ch`, traefik + coredns + metrics-server + local-path
- **Docker Compose** — ~13 stacków w `/home/pawel/stacks/`, 21 kontenerów

### Aplikacje
| App | Gdzie | Adres |
|---|---|---|
| nc (Django) — web | k3s `nc-prod` | nc.sowa.ch |
| nc — celery worker/beat/import + własny Postgres + Redis | Docker | — |
| PrestaShop 8.2 + MariaDB 11.4 | Docker | shop.sowa.ch |
| n8n | Docker | n8n.sowa.ch |
| landing page | Docker | sowa.ch |
| Soundcore/Streamlit monitor | host proc | spy.sowa.ch |

### Dane
- `postgres_shared` (PG18-alpine), `nc-postgres` (PG18-alpine), `nc-postgres-test` (PG18.1-alpine)
- **qdrant** (baza wektorowa) — qdrant.sowa.ch
- **MinIO** (S3) — minio.sowa.ch / minio-api.sowa.ch, dane na `/mnt/data2tb/minio`
- Redis (wymaga hasła, `CONFIG` zdisablowane — OK)

### Panele / admin
- pgAdmin (pgadmin.sowa.ch), Portainer (portainer.sowa.ch), Grafana (grafana.sowa.ch)

### Monitoring — **dwa stacki**
- **Netdata** (natywnie, ~7% CPU stale)
- **Prometheus + Grafana + cAdvisor + node-exporter + postgres-exporter** (~7 kontenerów, cAdvisor ~10% CPU stale) + OTel collector (4317) + statsd (8125)

### IDE
- Cursor remote server — **3 osobne okna**, ~30 procesów node, **5.8 GB RAM**, w każdym oknie rozszerzenie **Kilo Code** + Claude Code

### Backupy
- `pg_backup_*.sh` z crona, codziennie 02:00, 14 baz → `/srv/backups/postgres/` (retencja 7 dni). Ostatni: 2026-09-06 OK.
- `docker_cleanup.sh` co niedzielę 03:00

---

## 2. Co jest źle

### 🔴 Krytyczne

**2.1 Panele admin publicznie, bez żadnej autoryzacji na proxy**
`pgadmin`, `portainer`, `grafana`, `prometheus`, `qdrant`, `minio`, `n8n`, `nc-dev`, `asus`, `ej`, `ip`, `spy` — wszystkie na `*.sowa.ch`, w NPM `auth_basic=0`, brak Access List, brak IP allowlist.
- **Prometheus** i **qdrant** nie mają własnego logowania → każdy z internetu czyta metryki infra / kolekcje wektorów.
- pgAdmin / Portainer / MinIO / Grafana / n8n = tylko własne hasło aplikacji broni dostępu do baz, Dockera, obiektów S3 i automatyzacji.

**2.2 SSH — logowanie hasłem włączone**
`PasswordAuthentication yes` na porcie 22, `PermitRootLogin without-password` (root nadal wchodzi kluczem).
Serwer jest pod ciągłym bruteforce (logi pełne `kex_exchange_identification`, 265 banów).
Klucz dla użytkownika `pawel` jest skonfigurowany (10 wpisów w `authorized_keys`) — można bezpiecznie wyłączyć hasła.

**2.3 Brak swap**
31 GB RAM, ~250 MB wolne, `Swap: 0B`. Każdy skok pamięci → OOM killer ubija proces, zamiast łagodnej degradacji.

**2.4 Przeciążenie: load average 13–23 na 6 rdzeniach, 83% czasu w kernelu**
Źródło: **Cursor server** — 3 równoległe skany `rg --files --no-ignore --follow` całego `/home` (łącznie z `~/Recordings` 9.4 GB i `/mnt`), po jednym na każde z 3 otwartych okien + Kilo Code. To realnie dławi kontenery produkcyjne.

**2.5 Reboot wymagany od 2026-09-03**
Czeka nowy kernel `6.8.0-139` + `linux-base`. Działa stary `-138`.

### 🟠 Wysokie

**2.6 Dysk root 76% (106/148 GB), a dysk 2 TB pusty (13 GB / 1.9 TB)**
- `/var/lib/rancher` (k3s) = 40 GB
- `/var/lib/docker` = 38 GB (`overlay2` 34 GB)
- `/mnt/data2tb` używany tylko przez MinIO/Prestashop/część wolumenów

**2.7 ~40 GB śmieci Dockera**
- Build cache **21 GB (18 GB do odzyskania)**
- Dangling images ~4 GB (stare buildy `nc-django-app`, `landing`)
- `docker_cleanup.sh` robi tylko `image prune -f` (same dangling), **bez `builder prune` i bez `image prune -a`**

**2.8 Podwójna orkiestracja tej samej aplikacji nc**
web w k3s, celery + baza + redis w Dockerze, dwie bazy nc. Split-brain, trudny deploy, podwójny ingress (traefik obok NPM). k3s na 1 nodzie = stały narzut CPU/RAM (k3s server, kubelet, flannel, kube-router, traefik, coredns, metrics-server) i 40 GB dysku.

**2.9 Dwa stacki monitoringu robiące to samo**
Netdata + Prometheus/Grafana/cAdvisor/node-exporter. Razem ~17% CPU non-stop na nakładającą się funkcjonalność.

**2.10 Backupy — tylko lokalnie, jeden dysk, nietestowane**
- `/srv/backups/postgres` na **tym samym dysku** co bazy, retencja 7 dni, brak kopii off-site
- Brak backupu wolumenów: n8n, qdrant, MinIO, `database.sqlite` NPM, Portainer, stan k3s
- Restore nigdy nie testowany

### 🟡 Średnie

- **2.11** Tagi `:latest` na `n8n`, `minio`, `pgadmin`, `nginx-proxy-manager`, `qdrant`, `portainer` (stack observability jest przypięty — dobrze). Niedeterministyczny `compose pull`.
- **2.12** Niespójne wersje Postgres: `18-alpine` vs `18.1-alpine`.
- **2.13** Config drift: aktywne `/home/pawel/stacks/`, obok puste `/opt/vps/stacks/` (pliki 0-bajtowe), `/home/pawel/projects/nc/`, repo Ansible `/opt/vps` z niezacommitowanymi zmianami i starym HEAD. Repo nie odzwierciedla rzeczywistości.
- **2.14** Docker poza unattended-upgrades (u-u bierze tylko origin Ubuntu) — `docker-ce` 29.7→29.8, `containerd` czekają.
- **2.15** `nc-celery-*`: CMD `sleep 20 && celery ... --without-heartbeat --without-mingle`; uptime 3 h vs reszta dni/tygodnie → prawdopodobnie się restartowały.
- **2.16** Redis nasłuchuje na `172.17.0.1:6379` (docker0) — dostępny dla wszystkich kontenerów (hasło jest, ale lepsza dedykowana sieć).
- **2.17** `unattended-upgrades` bez `Automatic-Reboot` — kernel-e się instalują, ale nikt nie restartuje.
- **2.18** Zbędna powierzchnia na serwerze: Bluetooth, ModemManager, wpa_supplicant (chyba że świadomie — nagrywanie Soundcore przez BT / WiFi USB).
- **2.19** Szum w logach: `bt-record-healthcheck.service` faił, `systemd-networkd-wait-online` timeout, `rtw_8822bu ... failed to send h2c command`.
- **2.20** Pliki PrestaShop z datą mtime **2027** na `/mnt/data2tb/prestashop` — zegar/RTC skakał albo kontener ma złą strefę/datę.

---

## 3. Co poprawić — plan

### Dziś (30–60 min, największy zysk)
1. **Zamknij panele admin.** W NPM na pgadmin/portainer/grafana/prometheus/qdrant/minio/n8n:
   dodaj **Access List** (basic auth + `Allow` tylko LAN/VPN, `Deny all`).
   Docelowo: zdejmij je z publicznego proxy i wchodź przez **Tailscale/WireGuard** (teraz nie ma żadnego VPN).
2. **SSH** (`/etc/ssh/sshd_config.d/*`): `PasswordAuthentication no`, `PermitRootLogin no`.
   Najpierw w drugiej sesji potwierdź logowanie kluczem, potem `sudo systemctl restart ssh`.
3. **Odzyskaj ~20 GB:** `docker builder prune -af && docker image prune -af`
4. **Swap 8 GB:** `fallocate -l 8G /swapfile … swapon`, wpis w `/etc/fstab`, `vm.swappiness=10`.

### W tym tygodniu
5. **Zaplanuj reboot** (nowy kernel) — okno serwisowe.
6. **Odciąż root FS na dysk 2 TB:** przenieś `data-root` Dockera (`/etc/docker/daemon.json` → `"data-root": "/mnt/data2tb/docker"`) lub katalogi wolumenów; przenieś `/srv/backups` na 2 TB.
7. **Backupy off-site:** `restic`/`rclone` z `/srv/backups` + wolumenów do zewnętrznej lokalizacji (inny host / S3 / Backblaze). Raz przetestuj restore. Wydłuż retencję do 14–30 dni.
8. **Zdecyduj: k3s ALBO Compose dla nc.** Na jednym nodzie rekomendacja: zostaw Compose, usuń k3s → +40 GB dysku i stały spadek CPU. (Jeśli k3s ma zostać — przenieś tam też celery i usuń dockerowe nc.)
9. **Zdecyduj: Netdata ALBO Prometheus/Grafana.** Dla pojedynczego hosta Netdata wystarcza; jeśli zostaje Prometheus — zdejmij Netdata.
10. **Ogranicz Cursor:**
    - `~/.cursor-server` … w ustawieniach `files.watcherExclude` + `search.exclude` dla `**/Recordings/**`, `/mnt/**`, `**/.venv/**`, `**/node_modules/**`
    - plik `.cursorignore` w katalogach projektów
    - zamykaj nieużywane okna (teraz 3 × extension host + 3 × Kilo)
    - opcjon?nie: `systemd` slice z `CPUQuota=200%` na sesję użytkownika

### Higiena (stałe)
- Przypnij wersje obrazów (`n8n:1.x`, `minio:RELEASE.2025-…`, itd.).
- Ujednolić Postgres → `18.1-alpine` wszędzie.
- `docker_cleanup.sh`: dodaj `docker builder prune -f --filter until=168h` i `docker image prune -af --filter until=168h`.
- Zsynchronizuj rzeczywisty stan do repo Ansible `/opt/vps`; usuń martwe `/opt/vps/stacks/`, `/home/pawel/projects/nc` jeśli nieużywane.
- `Unattended-Upgrade::Automatic-Reboot "true"` + `Automatic-Reboot-Time "04:30"` (albo alert o `/var/run/reboot-required`).
- Alerty (Netdata/Grafana): dysk >85%, brak świeżego backupu >26 h, load>8 przez 15 min, cert <14 dni.
- Wyłącz Bluetooth/ModemManager/wpa_supplicant jeśli nieużywane (`systemctl disable --now`).
- Sprawdź datę/RTC (`timedatectl`), napraw mtime 2027 na PrestaShop.
- Napraw lub wyłącz `bt-record-healthcheck.service`.

### Dobre rzeczy (zostaw)
UFW + fail2ban skonfigurowane, TLS OK, codzienne backupy PG działają, stack observability przypięty do wersji, Redis z hasłem i zdisablowanym `CONFIG`, unattended-upgrades aktywne, k3s związany z LAN IP (nie 0.0.0.0), healthchecki na bazach.
