# Przywracanie backupu Nginx Proxy Manager

## Lokalizacja backupów

Backupy bazy danych NPM znajdują się w:
```
/srv/nginx-proxy-manager/data/
```

Dostępne backupy:
- `database.sqlite.old` - backup utworzony 10 stycznia 2026 o 14:31 (120KB) - **zalecany do przywrócenia**
- `database.sqlite.backup` - backup utworzony 10 stycznia 2026 o 14:31 (120KB)
- `database.sqlite` - aktualna baza danych (100KB - pusta po resecie)

## Jak przywrócić backup

### 1. Zatrzymaj kontener NPM
```bash
docker stop nginx-proxy-manager
```

### 2. Utwórz backup aktualnej bazy (na wszelki wypadek)
```bash
sudo cp /srv/nginx-proxy-manager/data/database.sqlite /srv/nginx-proxy-manager/data/database.sqlite.before_restore
```

### 3. Przywróć backup
```bash
sudo cp /srv/nginx-proxy-manager/data/database.sqlite.old /srv/nginx-proxy-manager/data/database.sqlite
sudo chown root:root /srv/nginx-proxy-manager/data/database.sqlite
sudo chmod 644 /srv/nginx-proxy-manager/data/database.sqlite
```

### 4. Uruchom kontener NPM
```bash
docker start nginx-proxy-manager
```

### 5. Sprawdź logi
```bash
docker logs nginx-proxy-manager --tail 50
```

## Alternatywnie: Przywrócenie przez Ansible

Jeśli chcesz przywrócić przez Ansible (po ręcznym skopiowaniu):

1. Skopiuj backup ręcznie (jak wyżej)
2. Uruchom playbook:
```bash
cd /opt/vps/ansible
ansible-playbook playbooks/nginx-proxy-manager-only.yml -i inventories/prod/hosts.ini
```

## Ważne uwagi

⚠️ **UWAGA**: Przywrócenie starej bazy danych może spowodować konflikt z nową wersją NPM jeśli był upgrade. 

Jeśli po przywróceniu zobaczysz błędy w logach związane z migracjami bazy danych:
- NPM może automatycznie spróbować zmigrować bazę
- Jeśli to nie zadziała, może być potrzebna ręczna migracja lub użycie starszej wersji obrazu NPM

## Sprawdzenie zawartości backupu (opcjonalnie)

Jeśli masz zainstalowany `sqlite3`:
```bash
sudo apt install sqlite3
sqlite3 /srv/nginx-proxy-manager/data/database.sqlite.old "SELECT name FROM sqlite_master WHERE type='table';"
```

## Data utworzenia backupów

- **database.sqlite.old**: 10 stycznia 2026, 14:31
- **database.sqlite.backup**: 10 stycznia 2026, 14:31

Oba backupy zostały utworzone przed reseciem bazy danych, który miał miejsce 10 stycznia 2026 o 14:33.
