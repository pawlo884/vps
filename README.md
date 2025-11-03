# Infra VPS - Repozytorium konfiguracji

Repozytorium z ustawieniami i automatyzacją dla VPS używając Ansible.

## Struktura

```
infra/
├── ansible/
│   ├── ansible.cfg           # Konfiguracja Ansible
│   ├── inventories/
│   │   └── prod/
│   │       ├── hosts.ini     # Hosty (IP, użytkownik)
│   │       └── group_vars/
│   │           └── all.yml   # Zmienne konfiguracyjne
│   ├── playbooks/
│   │   └── site.yml         # Główny playbook
│   └── roles/
│       ├── common/          # Hardening, firewall, podstawowe pakiety
│       ├── web/             # Nginx
│       └── db/              # PostgreSQL client
├── files/                   # Snapshoty aktualnych configów
│   ├── nginx/
│   ├── systemd/
│   └── docker/
└── scripts/                 # Skrypty pomocnicze
```

## Użycie

### Wymagania
```bash
sudo apt-get install ansible
```

### Dry-run (sprawdzenie zmian)
```bash
cd ~/infra
ansible-playbook ansible/playbooks/site.yml --check --diff
```

### Uruchomienie
```bash
ansible-playbook ansible/playbooks/site.yml
```

## Konfiguracja

### Zmiany IP/użytkownika VPS
Edytuj `ansible/inventories/prod/hosts.ini`:
```ini
[web]
vps ansible_host=192.168.50.31 ansible_user=pawel
```

### Zmiany ustawień (porty, pakiety, itp.)
Edytuj `ansible/inventories/prod/group_vars/all.yml`

## Bezpieczeństwo

⚠️ **NIE commitować**:
- Hasła/sekrety
- Klucze prywatne (.key, .pem)
- Pliki .env

Dla sekretów użyj:
- Ansible Vault
- SOPS + age
