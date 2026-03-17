# Landing Page Role

Rola Ansible do zarządzania landing page na sowa.ch.

## Tryby pracy

### 1. Tryb z repozytorium Git (zalecany)

Landing page może być przechowywany w osobnym repozytorium Git, co pozwala na łatwą edycję HTML/CSS bezpośrednio w repo.

**Konfiguracja w `all.yml`:**
```yaml
landing_repo_url: "git@github.com:pawlo884/sowa-landing.git"
landing_repo_branch: main
landing_repo_dir: ~/landing-page
```

**Struktura repo:**
```
sowa-landing/
├── index.html          # Główna strona HTML
├── css/
│   └── style.css      # Style CSS (opcjonalnie)
├── js/
│   └── app.js         # JavaScript (opcjonalnie)
├── images/            # Obrazy (opcjonalnie)
├── nginx.conf         # Konfiguracja nginx (opcjonalnie - jeśli nie podane, użyje domyślnego szablonu)
└── README.md          # Dokumentacja repo
```

Po każdym uruchomieniu playbook:
- Repo zostanie sklonowane/zaktualizowane
- Pliki z repo zostaną skopiowane do `/home/pawel/stacks/landing/html/`
- Kontener zostanie zrestartowany z nowymi plikami

**Jak edytować:**
1. Edytuj pliki w repo lokalnie
2. Commit i push do GitHub
3. Uruchom playbook: `ansible-playbook playbooks/landing-only.yml`
4. Zmiany zostaną automatycznie wdrożone

### 2. Tryb z szablonami Ansible (fallback)

Jeśli `landing_repo_url` jest puste, rola użyje szablonów Jinja2.

**Konfiguracja:**
```yaml
landing_repo_url: ""  # Puste = użyj szablonów
landing_applications:
  - name: "Portainer"
    url: "https://portainer.sowa.ch"
    description: "Zarządzanie kontenerami Docker"
```

## Konfiguracja aplikacji w repo

Jeśli używasz repo, możesz przechowywać listę aplikacji w pliku JSON:

**apps.json:**
```json
{
  "applications": [
    {
      "name": "Portainer",
      "url": "https://portainer.sowa.ch",
      "description": "Zarządzanie kontenerami Docker"
    },
    {
      "name": "Nginx Proxy Manager",
      "url": "https://npm.sowa.ch",
      "description": "Zarządzanie reverse proxy"
    }
  ]
}
```

Następnie w `index.html` załaduj ten plik przez JavaScript.

## Nginx Configuration

Jeśli w repo nie ma `nginx.conf`, rola użyje domyślnego szablonu z:
- Gzip compression
- Security headers
- Cache dla plików statycznych

Możesz dodać własny `nginx.conf` do repo, jeśli potrzebujesz specjalnej konfiguracji.

## Docker Compose

Kontener jest automatycznie tworzony przez rolę i jest podłączony do sieci `nginx_proxy_manager_network`, aby Nginx Proxy Manager mógł do niego forwardować ruch.

## Aktualizacja

Po zmianach w repo, uruchom:
```bash
cd ansible
ansible-playbook playbooks/landing-only.yml
```

Lub jeśli używasz pełnego playbook:
```bash
ansible-playbook playbooks/site.yml
```
