# Instrukcja: Montowanie dysku 2TB NVMe

## Po włożeniu dysku i włączeniu VPS:

### 1. Sprawdź czy dysk jest widoczny (na VPS):

```bash
ssh pawel@192.168.50.31
lsblk
```

Szukaj dysku ~2TB (np. `/dev/nvme0n1` lub `/dev/sdb`)

### 2. Zmień konfigurację Ansible:

W pliku `ansible/inventories/prod/group_vars/all.yml`:

```yaml
storage_configure: true
storage_disk_device: "/dev/nvme0n1"  # ZMIEŃ na właściwy dysk z lsblk!
```

### 3. Uruchom playbook przez Ansible (z WSL):

```bash
cd ~/vps/ansible
ansible-playbook playbooks/site.yml -K --tags storage
```

### 4. Co zostanie zrobione automatycznie:

- ✅ Sformatowanie dysku jako ext4 (label: data2tb)
- ✅ Montowanie do `/mnt/data2tb`
- ✅ Utworzenie katalogów dla PostgreSQL (prod/test)
- ✅ Utworzenie katalogów dla storage aplikacji
- ✅ Bind-mounty z 2TB do `/srv/postgres/*` i `/srv/volumes/*`
- ✅ Dodanie do `/etc/fstab` (automatyczne montowanie przy starcie)

### 5. Weryfikacja:

```bash
# Sprawdź czy dysk zamontowany
df -h | grep data2tb

# Sprawdź bind-mounty
mount | grep bind

# Sprawdź katalogi
ls -la /srv/postgres/*/data
ls -la /srv/volumes/
```

### 6. Uruchom PostgreSQL (jeśli jeszcze nie działa):

```bash
cd ~/vps/ansible
ansible-playbook playbooks/site.yml -K --tags postgres
```

## ⚠️ WAŻNE:

- **Przed formatowaniem:** Upewnij się że to właściwy dysk! Sprawdź przez `lsblk`
- **Backup:** Jeśli masz dane na starym dysku, najpierw je skopiuj
- **Partycjonowanie:** Playbook automatycznie utworzy jedną partycję na całym dysku

## Przeniesienie danych (jeśli masz już dane PostgreSQL na 500GB):

```bash
# Zatrzymaj kontenery
docker stop postgres_prod postgres_test 2>/dev/null

# Skopiuj dane (zachowaj uprawnienia)
sudo rsync -aHAX /srv/postgres/prod/data/ /mnt/data2tb/postgres/prod/data/
sudo rsync -aHAX /srv/postgres/test/data/ /mnt/data2tb/postgres/test/data/

# Uruchom ponownie
cd ~/stacks/db
docker compose up -d
```

