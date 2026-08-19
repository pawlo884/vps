# TODO — VPS `daktylowy`

Stan na 19.08.2026. Działamy po kolei, bez wielkich refaktorów naraz.

## Stan serwera (skrót)

- Ubuntu 24.04.4, i5-9500T, 32 GB RAM, swap wyłączony
- Dysk systemowy: LVM 150 GB z 474 GB (root ~47%)
- NVMe 1,9 TB: `/mnt/data2tb` (Postgres shared, MinIO, uploady)
- Docker Compose + Ansible + k3s obok siebie
- Reverse proxy: Nginx Proxy Manager (natywny nginx wyłączony)
- Aplikacja: Django `nc` (blue-green), Celery, Redis, Next.js landing, n8n
- Bazy: `nc-postgres-1` (5432), `nc-postgres-test` (5433), `postgres_shared` (pada), Qdrant
- Monitoring: Netdata systemd (~2,2 GB RAM) + Prometheus/Grafana

---

## 1. Bezpieczeństwo (najpierw)

Wgrane na VPS 19.08.2026: compose na `127.0.0.1`, Netdata, Streamlit, trasy `npm.sowa.ch` / `spy.sowa.ch`.
Publicznie zostaje **22 / 80 / 443**. Do dokończenia: k3s `:6443`, UFW (stare allow), fail2ban nginx.

Panele zostają dostępne przez domeny NPM (Cloudflare) albo tunel:
`ssh -L 81:127.0.0.1:81 -L 9000:127.0.0.1:9000 -L 5050:127.0.0.1:5050 -L 19999:127.0.0.1:19999 pawel@HOST`

- [x] Szablony: reszta usług na `127.0.0.1`, publicznie 80/443 (NPM)
- [x] Szablony: Postgres 5432/5433, Qdrant 6333/6334 (MinIO — apply na VPS)
- [x] Szablony: Portainer, pgAdmin, n8n, NPM :81, Netdata
- [x] Szablony: Django 8000 + Flower 5555
- [x] k3s API: `bind-address: 127.0.0.1` w Ansible
- [x] Panele przez NPM/Cloudflare albo SSH tunnel (Tailscale nie instalujemy teraz)
- [x] UFW w Ansible (`ufw_enabled: true`, tylko 22/80/443)
- [x] Fail2ban: SSH + jail NPM/nginx
- [x] **Apply na VPS** — Docker na `127.0.0.1` (publicznie 22/80/443), Netdata, Streamlit, trasy NPM
- [ ] k3s API `:6443` (i kubelet `:10250`) nadal na `*`
- [ ] UFW: wyciąć stare allow (81, 9000, …) — Docker już ich nie wystawia
- [ ] Fail2ban nginx — kod w repo, na serwerze jeszcze nie

## 2. Naprawa Postgres `shared`

Kontener `postgres_shared` (`postgres:18`) restartuje się w pętli — zły mount pod PG18 (`/var/lib/postgresql/data` vs nowy layout). Backupy `shared` przez to nic nie zrzucają.

- [ ] Ustalić wersję danych na dysku (PG16/17/18)
- [ ] Albo pin `postgres:16` i zostawić stary mount
- [ ] Albo migracja `pg_upgrade` pod layout PG18
- [ ] Sprawdzić, czy cron backup `shared` znów działa
- [ ] Decyzja: jedna instancja Postgres dla aplikacji (`shared` **albo** `nc-postgres-1`), nie dwie równoległe

## 3. Celery

`nc-celery-default` / `import` padały od razu po starcie (~18–60 s uptime).

- [ ] Sprawdzić logi workerów i naprawić przyczynę restartów
- [ ] Potwierdzić, że beat + obie kolejki trzymają się stabilnie

## 4. Jeden runtime, jeden proxy, jeden monitoring

- [ ] Decyzja: **Docker Compose** albo **k3s** — nie oba. Ansible ogarnia tylko Compose
- [ ] Jeśli k3s nieużywany / eksperyment: wyłączyć i posprzątać
- [ ] Proxy: zostawić **NPM** albo przenieść do Caddy/Traefik w Ansible. Usunąć martwy nginx systemowy
- [ ] Monitoring: zostawić **Prometheus + Grafana**. Netdata wyłączyć albo ograniczyć RAM (256–512 MB)
- [ ] Dodać limity RAM/CPU tam, gdzie ich nie ma (Postgres, n8n, pgAdmin, Prometheus, cAdvisor)

## 5. Backup

Lokalny `pg_dump` jest. Crony są zduplikowane. Rola `backups` jest w `site.yml`, ale **nie ma jej w repo**.

- [ ] Przywrócić rolę `backups` do repo (żeby playbook nie był rozjechany z serwerem)
- [ ] Posprzątać zduplikowane wpisy cron
- [ ] Dodać kopię **offsite** (`restic` lub `rclone` na B2/S3)
- [ ] n8n: przenieść z SQLite na Postgres

## 6. Porządek Ansible / IaC

- [ ] Zsynchronizować kod z serwerem: MinIO, k3s (albo usunąć), blue-green, observability są poza `site.yml`
- [ ] Pinować tagi obrazów — bez `:latest` (n8n, Qdrant, MinIO, Portainer, NPM, pgAdmin)
- [ ] Sekrety w Ansible Vault, nie luźny `secrets.yml`
- [ ] Instalacja Dockera z repo (Ubuntu/Docker CE), nie `curl | sh`
- [ ] `app_manage_containers: false` — ustalić źródło prawdy: Compose na serwerze **albo** Ansible, nie oba
- [ ] GitLab Runner: włączyć i ogarnąć w Ansible albo usunąć z playbooka

## 7. Zasoby dysku i RAM

- [ ] Rozważyć rozszerzenie LVM root (~324 GB wolne w VG) zanim Docker zapełni `/`
- [ ] Mały swap/zram (2–4 GB) — swap jest wyłączony
- [ ] Cotygodniowe czyszczenie Dockera: potwierdzić, że timer/cron działa i nie kasuje potrzebnych obrazów

---

## Kolejność robienia

1. Bezpieczeństwo portów (pkt 1)
2. Naprawa `postgres_shared` (pkt 2)
3. Celery (pkt 3)
4. Netdata vs Prometheus (część pkt 4)
5. Backup + rola Ansible (pkt 5)
6. Reszta porządków (k3s, pin tagów, LVM, Vault)
