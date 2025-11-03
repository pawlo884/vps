# Analiza brakujących elementów w planie VPS

## ✅ Co już mamy w Ansible:

1. **Ubuntu Server 24.04** - zainstalowany na VPS
2. **Podstawowe pakiety** - git, curl, wget, htop, ufw, fail2ban, unattended-upgrades
3. **Firewall (UFW)** - skonfigurowany (porty 22, 80, 443)
4. **Docker** - zainstalowany (docker_install: true)
5. **Nginx** - zainstalowany (nginx_install: true)
6. **SSH hardening** - PasswordAuthentication=no (manualne, nie w Ansible)
7. **Audit playbook** - sprawdzanie stanu VPS

## ❌ Co brakuje w Ansible (z planu):

### 1. **Konfiguracja dysków (2 TB NVMe)**
   - Formatowanie NVMe (ext4, label=data2tb)
   - Montowanie do `/mnt/data2tb`
   - Bind-mounty dla Postgresa (`/srv/postgres/*`)
   - Bind-mounty dla aplikacji (`/srv/volumes`)
   - `/etc/fstab` z bind-mountami
   - **Brakuje:** Rola `storage` lub sekcja w `common`

### 2. **PostgreSQL w Dockerze**
   - Docker Compose dla Postgresa (prod/test/misc)
   - Wieloinstancyjna konfiguracja (10 baz)
   - Parametry tuning (shared_buffers, effective_cache_size itp.)
   - Sieć Docker (`dbnet`)
   - Healthcheck
   - **Brakuje:** Rola `postgres` z docker-compose + templates

### 3. **Reverse proxy (Caddy)**
   - Docker Compose dla Caddy
   - Caddyfile template
   - Sieć Docker (`proxy`)
   - Automatyczne SSL (Let's Encrypt)
   - **Brakuje:** Rola `proxy` lub `caddy`

### 4. **Backupy Postgresa**
   - Skrypt backupowy (`/usr/local/bin/pg_backup.sh`)
   - Cron per instancja (prod/test/misc)
   - Rotacja backupów (7 dni)
   - **Brakuje:** Rola `backups` lub sekcja w `postgres`

### 5. **Monitoring (Netdata)**
   - Docker Compose dla Netdata
   - Port 19999
   - **Brakuje:** Rola `monitoring`

### 6. **Hardening systemu**
   - sysctl (vm.swappiness=10)
   - journald limit (SystemMaxUse=200M)
   - Docker logi limit (daemon.json)
   - fstrim.timer (włączony)
   - **Brakuje:** Sekcja w `common` lub rola `hardening`

### 7. **Docker compose plugin**
   - Instalacja `docker-compose-plugin`
   - **Brakuje:** W `common` role (jest tylko Docker)

### 8. **Konfiguracja Docker daemon**
   - `/etc/docker/daemon.json` z limitami logów
   - **Brakuje:** W `common` role

## 📋 Proponowana struktura ról:

```
ansible/
├── roles/
│   ├── common/          ✅ Istnieje (rozszerzyć o hardening)
│   ├── web/             ✅ Istnieje (Nginx)
│   ├── db/              ⚠️ Istnieje (tylko psql client, wyłączony)
│   ├── storage/         ❌ NOWA - dyski i montowania
│   ├── postgres/        ❌ NOWA - PostgreSQL w Dockerze
│   ├── proxy/           ❌ NOWA - Caddy reverse proxy
│   ├── backups/         ❌ NOWA - skrypty backupów
│   └── monitoring/      ❌ NOWA - Netdata
```

## 🎯 Priorytetyzacja:

### Wysoki priorytet (przed migracją z DO):
1. **storage** - dyski 2TB NVMe
2. **postgres** - wieloinstancyjny PostgreSQL
3. **backups** - skrypty backupów
4. **hardening** - sysctl, journald, docker logs

### Średni priorytet:
5. **proxy** - Caddy (można później)
6. **monitoring** - Netdata (można później)

### Niski priorytet:
7. Ulepszenia istniejących ról

## 📝 Dodatkowe uwagi:

- **Nginx vs Caddy:** Plan mówi o Caddy, ale masz już Nginx. Decyzja: Caddy (łatwiejsze SSL) czy zostajemy przy Nginx?
- **500 GB vs 2 TB:** Plan zakłada przejście z 500 GB na 2 TB. Ansible powinien obsługiwać oba scenariusze.
- **Wieloinstancyjność:** Plan zakłada kilka instancji Postgresa (prod/test/misc). Role powinny być elastyczne.
- **Hasła i sekrety:** Docker Compose powinien używać `.env` (nie commitować do repo).

## 🔧 Co zrobić teraz:

1. Rozszerzyć `common` o hardening (sysctl, journald, docker logs)
2. Utworzyć rolę `storage` dla dysków 2TB
3. Utworzyć rolę `postgres` z docker-compose (wieloinstancyjna)
4. Utworzyć rolę `backups` ze skryptami i cronami
5. Utworzyć rolę `proxy` dla Caddy (opcjonalnie)
6. Utworzyć rolę `monitoring` dla Netdata (opcjonalnie)

