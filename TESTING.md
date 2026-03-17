# Przewodnik testowania Ansible playbook

## Sprawdzenie składni

```bash
cd ~/vps/ansible
ansible-playbook playbooks/site.yml --syntax-check
```

## Dry-run (sprawdzenie zmian bez wprowadzania)

```bash
cd ~/vps/ansible
ansible-playbook playbooks/site.yml --check --diff -K
```

## Uruchomienie pełnego playbooka

```bash
cd ~/vps/ansible
ansible-playbook playbooks/site.yml -K
```

## Testowanie pojedynczych ról

### Tylko hardening (common):
```bash
ansible-playbook playbooks/site.yml -K --tags common
```

### Tylko PostgreSQL:
```bash
ansible-playbook playbooks/site.yml -K --tags postgres
```

### Tylko backupy:
```bash
ansible-playbook playbooks/site.yml -K --tags backups
```

## Przed uruchomieniem - sprawdź:

1. **Hasła PostgreSQL** - zmień w `ansible/inventories/prod/group_vars/all.yml`:
   - `postgres_instances[0].db_password` dla prod
   - `postgres_instances[1].db_password` dla test

2. **Katalogi danych** - upewnij się że istnieją lub zostaną utworzone:
   - `/srv/postgres/prod/data`
   - `/srv/postgres/prod/backups`
   - `/srv/postgres/test/data`
   - `/srv/postgres/test/backups`

3. **Caddy** - jeśli chcesz użyć, dodaj domeny w `all.yml`:
   ```yaml
   proxy_domains:
     - domain: example.com
       email: admin@example.com
       backend: app:8000
   ```

## Weryfikacja po uruchomieniu

### Sprawdź kontenery Docker:
```bash
ssh pawel@192.168.50.31
docker ps
```

### Sprawdź logi PostgreSQL:
```bash
docker logs postgres_prod
docker logs postgres_test
```

### Sprawdź backupy:
```bash
ls -lh /srv/postgres/*/backups/
```

### Sprawdź crony:
```bash
crontab -l
```

### Sprawdź Netdata:
```bash
curl http://localhost:19999
```

## Rozwiązywanie problemów

### Jeśli Docker nie działa:
```bash
sudo systemctl status docker
sudo usermod -aG docker pawel
newgrp docker
```

### Jeśli kontenery się nie uruchamiają:
```bash
cd ~/stacks/db
docker compose logs
docker compose ps
```

### Jeśli brakuje uprawnień:
```bash
sudo chown -R pawel:pawel /srv/postgres
sudo chown -R pawel:pawel ~/stacks
```

