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
| `ANSIBLE_SECRETS` | **File** lub **Variable** | Zawartość pliku `ansible/inventories/prod/group_vars/secrets.yml` | ✅ Tak |

**Jak uzyskać klucz SSH:**
```bash
cat ~/.ssh/id_ed25519
# Skopiuj całą zawartość (łącznie z -----BEGIN/END-----)
```

**Jak przygotować ANSIBLE_SECRETS (dwie opcje):**
- **Typ File:** przy dodawaniu zmiennej wybierz **Type: File**, wklej całą zawartość `ansible/inventories/prod/group_vars/secrets.yml`. GitLab utworzy plik i poda ścieżkę w zmiennej.
- **Typ Variable:** wybierz **Type: Variable**, w polu wartość wklej **całą** zawartość pliku `secrets.yml` (wieloliniowy YAML). Pipeline zapisze to do pliku przed deployem.

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

## Deploy na prod – kroki (każdy deploy)

1. **Zmienne w GitLab** (Settings → CI/CD → Variables):
   - `ANSIBLE_SSH_PRIVATE_KEY` – klucz prywatny SSH (Variable, chroniona).
   - `ANSIBLE_HOST` – IP lub hostname VPS prod (Variable).
   - `ANSIBLE_SECRETS` – **cała** zawartość `ansible/inventories/prod/group_vars/secrets.yml` (Type: **File**). Po każdej zmianie sekretów (hasła, n8n, app itd.) zaktualizuj tę zmienną w GitLab.

2. **Kod na `main`:**
   - Zrób commit i push (playbooki, role, `all.yml` – **nie** commitujesz `secrets.yml`).

3. **Uruchomienie deployu:**
   - GitLab → **CI/CD → Pipelines** → wejdź w pipeline z brancha `main`.
   - Opcjonalnie: uruchom **dry_run** (manual) – symulacja bez zmian.
   - Uruchom **deploy_prod** (manual) – faktyczny deploy.

4. **Po deployu (np. n8n):**
   - W **Nginx Proxy Manager** (np. https://npm.sowa.ch): dodaj Proxy Host: domena `n8n.sowa.ch` → Forward hostname `n8n`, port `5678` → SSL: Request certificate.

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
