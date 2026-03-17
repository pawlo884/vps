# Infra VPS - Repozytorium konfiguracji

Repozytorium z ustawieniami i automatyzacją dla VPS używając Ansible.

## ❓ Jak to działa?

**Ansible działa na twoim lokalnym komputerze**, a nie na VPS. To narzędzie typu "control node" - łączy się z VPS przez SSH i wykonuje na nim komendy.

**Przepływ pracy:**
1. Twój komputer (z Ansible) → SSH → VPS
2. Ansible wysyła komendy przez SSH (np. `apt install`, `systemctl start`)
3. VPS wykonuje komendy i zwraca wyniki
4. **Na VPS potrzebny jest tylko Python 3** (do wykonywania modułów Ansible)
5. **Ansible jako narzędzie NIE musi być na VPS** - tylko na lokalnym komputerze

**Wymagania na VPS:**
- ✅ SSH (zwykle już jest)
- ✅ Python 3 (Ansible automatycznie go instaluje jeśli brakuje)
- ❌ Ansible jako narzędzie NIE jest potrzebny na VPS

**Alternatywy (bez Ansible):**
- Ręczne połączenie SSH i wykonywanie komend jedna po drugiej
- Wysyłanie skryptów bash przez `scp` i uruchamianie ich na VPS

**Dlaczego Ansible?**
- ✅ Automatyzacja - wszystkie zmiany w jednym playbook
- ✅ Powtarzalność - zawsze ten sam wynik
- ✅ Bezpieczeństwo - możesz sprawdzić zmiany przed wprowadzeniem (`--check`)
- ✅ Dokumentacja - konfiguracja jest w kodzie (version control)

## 🚀 Szybki start

### 1. Instalacja Ansible (TYLKO na lokalnym komputerze, nie na VPS!)

**Linux/Ubuntu:**
```bash
sudo apt-get update
sudo apt-get install ansible
```

**macOS:**
```bash
brew install ansible
```

**Windows:**
```bash
# Przez WSL lub użyj Ansible w Dockerze
```

### 2. Konfiguracja klucza SSH

Upewnij się, że masz skonfigurowany klucz SSH i możesz łączyć się z VPS bez hasła:

```bash
# Jeśli nie masz klucza, wygeneruj:
ssh-keygen -t ed25519 -C "twoj@email.com"

# Skopiuj klucz publiczny na VPS:
ssh-copy-id pawel@192.168.50.31

# Lub ręcznie:
cat ~/.ssh/id_ed25519.pub | ssh pawel@192.168.50.31 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

### 3. Sprawdzenie połączenia

```bash
# Użyj skryptu pomocniczego:
./scripts/check-vps.sh

# Lub bezpośrednio:
cd ansible
ansible all -m ping
```

### 4. Pierwsze uruchomienie playbook

```bash
# Sprawdź co zostanie zmienione (dry-run):
./scripts/dry-run.sh

# Uruchom pełną konfigurację:
./scripts/run-ansible.sh
```

## 📁 Struktura

```
vps/
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
│   └── systemd/
├── scripts/                 # Skrypty pomocnicze
│   ├── run-ansible.sh       # Uruchom playbook
│   ├── check-vps.sh         # Sprawdź połączenie
│   ├── dry-run.sh           # Dry-run przed zmianami
│   └── ssh-vps.sh           # Połącz się z VPS przez SSH
└── README.md
```

## 🛠️ Zarządzanie VPS

### Podstawowe komendy

**Sprawdzenie połączenia:**
```bash
./scripts/check-vps.sh
```

**Sprawdzenie zmian przed wprowadzeniem (dry-run):**
```bash
./scripts/dry-run.sh
```

**Uruchomienie pełnej konfiguracji:**
```bash
./scripts/run-ansible.sh
```

**Połączenie z VPS przez SSH:**
```bash
./scripts/ssh-vps.sh
```

### Bezpośrednie użycie Ansible

Jeśli wolisz używać Ansible bezpośrednio:

```bash
cd ansible

# Ping do VPS
ansible all -m ping

# Sprawdzenie zmian (dry-run)
ansible-playbook playbooks/site.yml --check --diff

# Uruchomienie playbook
ansible-playbook playbooks/site.yml

# Uruchomienie tylko wybranej roli
ansible-playbook playbooks/site.yml --tags common

# Sprawdzenie statusu usług
ansible all -m shell -a "systemctl status nginx"
```

### Przykładowe zadania

**Uruchomienie komendy na VPS:**
```bash
cd ansible
ansible all -m shell -a "df -h"
ansible all -m shell -a "docker ps"
ansible all -m shell -a "systemctl status nginx"
```

**Aktualizacja tylko wybranych pakietów:**
```bash
cd ansible
ansible-playbook playbooks/site.yml --tags common
```

## ⚙️ Konfiguracja

### Zmiany IP/użytkownika VPS

Edytuj `ansible/inventories/prod/hosts.ini`:
```ini
[web]
vps ansible_host=192.168.50.31 ansible_user=pawel
```

Po zmianie sprawdź połączenie:
```bash
./scripts/check-vps.sh
```

### Sekrety i hasła

**WAŻNE:** Hasła i sekrety są w osobnym pliku, który NIE jest commitowany:
- `ansible/inventories/prod/group_vars/secrets.yml` - prawdziwe hasła (w .gitignore)
- `ansible/inventories/prod/group_vars/secrets.yml.example` - przykład (commitowany)

**Pierwsza konfiguracja:**
```bash
cd ansible/inventories/prod/group_vars
cp secrets.yml.example secrets.yml
# Edytuj secrets.yml i uzupełnij hasła
```

### Zmiany ustawień (porty, pakiety, itp.)

Edytuj `ansible/inventories/prod/group_vars/all.yml`:

```yaml
# Firewall - dodaj/usuń porty
ufw_allowed_ports:
  - { port: 22, proto: tcp, comment: "SSH" }
  - { port: 80, proto: tcp, comment: "HTTP" }
  - { port: 443, proto: tcp, comment: "HTTPS" }

# Pakiety - dodaj/usuń
base_packages:
  - git
  - curl
  - wget
  # ...
```

Po zmianach uruchom:
```bash
./scripts/dry-run.sh  # sprawdź zmiany
./scripts/run-ansible.sh  # wprowadź zmiany
```

## 🔒 Bezpieczeństwo

⚠️ **NIE commitować**:
- Hasła/sekrety
- Klucze prywatne (.key, .pem)
- Pliki .env
- Dane wrażliwe w `group_vars/`

**Dla sekretów użyj:**
- Ansible Vault
- SOPS + age
- Zmienne środowiskowe

**Obecna konfiguracja:**
- SSH tylko na klucz (brak haseł)
- Firewall UFW (domyślnie blokuje przychodzące)
- Fail2ban (ochrona przed brute-force)
- Automatyczne aktualizacje bezpieczeństwa

## 📝 Co robi playbook?

### Rola `common`:
- Aktualizuje cache apt
- Instaluje podstawowe pakiety (git, curl, wget, htop, ufw, fail2ban, itp.)
- Konfiguruje automatyczne aktualizacje bezpieczeństwa
- Konfiguruje firewall UFW (porty 22, 80, 443)

### Rola `web`:
- Instaluje i konfiguruje Nginx
- Włącza i uruchamia usługę Nginx
- Testuje konfigurację przed restartem

### Rola `db`:
- Instaluje PostgreSQL client (do zarządzania bazami)

## 📌 FAQ

**Q: Zainstalowałem Ansible na VPS - czy to potrzebne?**  
A: Nie - Ansible jako narzędzie działa tylko na lokalnym komputerze. Na VPS potrzebny jest tylko Python 3 (który jest już w `base_packages`). Możesz usunąć Ansible z VPS:
```bash
ssh pawel@192.168.50.31
sudo apt remove ansible
```

**Q: Co dokładnie jest potrzebne na VPS?**  
A: 
- Python 3 (instaluje się automatycznie przez `base_packages`)
- SSH (zwykle już jest)
- Ansible jako narzędzie NIE jest potrzebny

## 🐛 Rozwiązywanie problemów

**Problem: "Host key checking failed"**
- Rozwiązanie: już jest wyłączone w `ansible.cfg` (`host_key_checking = False`)

**Problem: "Permission denied (publickey)"**
- Rozwiązanie: upewnij się, że klucz SSH jest skopiowany na VPS:
  ```bash
  ssh-copy-id pawel@192.168.50.31
  ```

**Problem: "Connection refused"**
- Sprawdź czy VPS działa i czy IP jest poprawne
- Sprawdź firewall na VPS i routerze (port 22 musi być otwarty)

**Problem: Playbook się nie uruchamia**
- Sprawdź czy jesteś w odpowiednim katalogu
- Użyj skryptów pomocniczych z katalogu `scripts/`

## 📚 Więcej informacji

- [Dokumentacja Ansible](https://docs.ansible.com/)
- [UFW - Firewall](https://help.ubuntu.com/community/UFW)
- [Nginx](https://nginx.org/en/docs/)
