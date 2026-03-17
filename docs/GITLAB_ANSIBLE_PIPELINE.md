# Zarządzanie serwerem przez GitLab i Ansible Pipeline

## Co to jest i jak działa?

**GitLab CI/CD + Ansible** pozwala na automatyczne zarządzanie serwerem VPS przy każdym pushu do repozytorium. Zamiast ręcznego uruchamiania `ansible-playbook` na swoim komputerze, pipeline GitLab:

1. **Lint** – sprawdza składnię YAML i Ansible
2. **Test** – weryfikuje playbook (`--syntax-check`, opcjonalnie `--check --diff`)
3. **Deploy** – łączy się z VPS przez SSH i uruchamia playbook (ręcznie, tylko na `main`)

```
Push do main → GitLab Runner → SSH do VPS → Ansible wykonuje playbook → Serwer zaktualizowany
```

---

## Co musisz zrobić krok po kroku

### 1. Skonfiguruj zmienne CI/CD w GitLab

W repozytorium: **Settings → CI/CD → Variables** (Expand) dodaj:

| Zmienna | Typ | Wartość | Chroniona |
|---------|-----|---------|-----------|
| `ANSIBLE_SSH_PRIVATE_KEY` | Variable | Zawartość klucza prywatnego SSH (np. `~/.ssh/id_ed25519`) | ✅ Tak |
| `ANSIBLE_HOST` | Variable | IP lub hostname serwera (np. `192.168.50.31`) | ✅ Tak |
| `ANSIBLE_SECRETS` | File | Zawartość pliku `ansible/inventories/prod/group_vars/secrets.yml` | ✅ Tak |

**Jak uzyskać klucz SSH:**
```bash
cat ~/.ssh/id_ed25519
# Skopiuj całą zawartość (łącznie z -----BEGIN/END-----)
```

**Jak przygotować ANSIBLE_SECRETS (typ File):**
1. W GitLab przy dodawaniu zmiennej wybierz **Type: File**
2. W polu wartość wklej całą zawartość pliku `ansible/inventories/prod/group_vars/secrets.yml`
3. GitLab utworzy tymczasowy plik – zmienna będzie zawierać ścieżkę do niego (używana w pipeline przez `cp`)

**Uwaga:** Klucz musi być dodany do `~/.ssh/authorized_keys` na serwerze (użytkownik `pawel`).

---

### 2. Inventory dla CI (już skonfigurowane)

Pipeline automatycznie generuje `hosts_ci.ini` z hostem z zmiennej `ANSIBLE_HOST`. Lokalny `hosts.ini` (127.0.0.1) pozostaje do testów na swoim komputerze.

---

### 3. Sekrety (secrets.yml)

Playbook ładuje `secrets.yml` z `group_vars/`. Ten plik jest w `.gitignore` – nie trafi do GitLab.

**Rozwiązanie (już w pipeline):** Zmienna `ANSIBLE_SECRETS` (typ File) – GitLab tworzy tymczasowy plik, pipeline kopiuje go do `group_vars/secrets.yml` przed uruchomieniem playbooka.

---

### 4. Dostęp GitLab Runnera do serwera

- Serwer musi być dostępny z sieci, w której działa GitLab Runner (publiczny IP lub VPN).
- Port 22 (SSH) musi być otwarty.
- Użytkownik `pawel` na serwerze musi mieć klucz z `ANSIBLE_SSH_PRIVATE_KEY` w `authorized_keys`.

---

### 5. Przepływ pipeline

| Stage | Job | Kiedy | Co robi |
|-------|-----|-------|---------|
| lint | lint_ansible | MR, każdy branch | yamllint, ansible-lint |
| test | syntax_check | MR, każdy branch | `ansible-playbook --syntax-check` |
| test | dry_run | main, ręcznie | `--check --diff` (symulacja) |
| deploy | deploy_prod | main, ręcznie | Pełny deploy na produkcję |

**Deploy jest ręczny** – musisz wejść w pipeline i kliknąć „Play” przy `deploy_prod`.

---

## Podsumowanie – minimalna konfiguracja

1. **GitLab Variables:** `ANSIBLE_SSH_PRIVATE_KEY`, `ANSIBLE_HOST`, `ANSIBLE_SECRETS` (File)
2. **Inventory:** generowane automatycznie w pipeline z `$ANSIBLE_HOST`
3. **Sekrety:** zmienna `ANSIBLE_SECRETS` (typ File) z zawartością `secrets.yml`
4. **Serwer:** klucz SSH w `authorized_keys`, port 22 otwarty, dostępny z sieci GitLab Runnera

---

## Testowanie lokalne przed CI

```bash
cd ansible
ansible all -m ping
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook playbooks/site.yml --check --diff
```

---

## Dokumentacja

- [GitLab CI/CD Variables](https://docs.gitlab.com/ee/ci/variables/)
- [Ansible Inventory](https://docs.ansible.com/ansible/latest/inventory_guide/index.html)
