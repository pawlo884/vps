# Konfiguracja Landing Page z repozytorium Git

## Przegląd

Landing page może być teraz przechowywany w osobnym repozytorium Git, co pozwala na łatwą edycję HTML/CSS bezpośrednio w repo bez potrzeby modyfikowania szablonów Ansible.

## Krok 1: Utworzenie repozytorium

1. Utwórz nowe repozytorium na GitHub (np. `sowa-landing`)
2. Sklonuj je lokalnie:
   ```bash
   git clone git@github.com:pawlo884/sowa-landing.git
   cd sowa-landing
   ```

## Krok 2: Struktura repozytorium

**Jeśli używasz Next.js (zalecane):**
```
sowa-landing/
├── app/
│   ├── page.tsx       # Główna strona
│   ├── layout.tsx     # Layout aplikacji
│   └── globals.css    # Style globalne
├── components/        # Komponenty React
├── public/            # Pliki statyczne (obrazy, favicon)
├── package.json       # Zależności npm
├── next.config.ts     # Konfiguracja Next.js (musi mieć output: "standalone")
├── Dockerfile         # Dockerfile (opcjonalnie - zostanie wygenerowany przez Ansible)
├── .gitignore
└── README.md
```

**Jeśli używasz statycznych plików HTML (stary tryb):**
```
sowa-landing/
├── index.html          # Główna strona HTML
├── css/
│   └── style.css      # Style CSS
├── js/
│   └── app.js         # JavaScript
├── images/            # Obrazy
└── nginx.conf         # Konfiguracja nginx (opcjonalnie)
```

## Krok 3: Konfiguracja Next.js

**Ważne:** Next.js jest już skonfigurowany w repo. Upewnij się że `next.config.ts` ma:

```typescript
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",  // Wymagane dla Docker!
};

export default nextConfig;
```

**Jeśli używasz statycznych plików HTML (stary tryb):**

Przykładowy `index.html`:
```html
<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sowa.ch - Strona główna</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <div class="container">
        <h1>🦉 Sowa.ch</h1>
        <p class="subtitle">Witaj na stronie głównej</p>
        <div id="apps-container"></div>
    </div>
    <script src="js/app.js"></script>
</body>
</html>
```

## Krok 4: Przykładowy apps.json

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
    },
    {
      "name": "Aplikacja Django",
      "url": "https://app.sowa.ch",
      "description": "Główna aplikacja Django"
    }
  ]
}
```

## Krok 5: JavaScript do ładowania aplikacji

**js/app.js:**
```javascript
fetch('apps.json')
  .then(response => response.json())
  .then(data => {
    const container = document.getElementById('apps-container');
    container.innerHTML = data.applications.map(app => `
      <a href="${app.url}" class="app-card" target="_blank" rel="noopener noreferrer">
        <h3>${app.name}</h3>
        <p>${app.description || 'Kliknij, aby przejść'}</p>
      </a>
    `).join('');
  })
  .catch(error => console.error('Błąd ładowania aplikacji:', error));
```

## Krok 6: Konfiguracja Ansible

W `ansible/inventories/prod/group_vars/all.yml`:

```yaml
landing_repo_url: "git@github.com:pawlo884/sowa-landing.git"
landing_repo_branch: main
landing_repo_dir: ~/landing-page
```

## Krok 7: Pierwsze wdrożenie (tylko raz)

⚠️ **Pierwsze wdrożenie wymaga ręcznego uruchomienia Ansible** - to skonfiguruje kontener i sklonuje repo na VPS.

1. Upewnij się, że `landing_repo_url` jest ustawione w `ansible/inventories/prod/group_vars/all.yml`:
   ```yaml
   landing_repo_url: "git@github.com:pawlo884/sowa-landing.git"
   ```

2. Commit i push zmian do repo (jeśli jeszcze nie zrobiłeś):
   ```bash
   git add .
   git commit -m "Initial landing page"
   git push origin main
   ```

3. Uruchom playbook (tylko pierwszy raz):
   ```bash
   cd ansible
   ansible-playbook playbooks/landing-only.yml
   ```

4. **Po pierwszym wdrożeniu** - skonfiguruj GitHub Actions (patrz sekcja "Konfiguracja automatycznego wdrożenia" poniżej), a potem wystarczy commit + push! 🚀

## Aktualizacja landing page

### Opcja 1: Automatyczne wdrożenie przez GitHub Actions (ZALECANE) ⚡

Po skonfigurowaniu GitHub Actions, wystarczy zrobić commit i push - reszta dzieje się automatycznie!

1. Edytuj pliki w repo lokalnie
2. Commit i push:
   ```bash
   git add .
   git commit -m "Update landing page"
   git push origin main
   ```
3. **Gotowe!** GitHub Actions automatycznie zaktualizuje landing page na VPS 🚀

### Opcja 2: Ręczne wdrożenie (jeśli nie używasz GitHub Actions)

1. Edytuj pliki w repo lokalnie
2. Commit i push:
   ```bash
   git add .
   git commit -m "Update landing page"
   git push origin main
   ```
3. Uruchom playbook:
   ```bash
   ansible-playbook playbooks/landing-only.yml
   ```

## Konfiguracja automatycznego wdrożenia (GitHub Actions)

### Krok 1: Dodaj secrets do GitHub

W repozytorium landing page (`sowa-landing`) → **Settings** → **Secrets and variables** → **Actions**, dodaj:

1. **VPS_HOST**: IP lub domena twojego VPS (np. `192.168.50.31` lub `sowa.ch`)
2. **VPS_USER**: `pawel`
3. **VPS_SSH_KEY**: zawartość klucza prywatnego SSH (np. `~/.ssh/id_ed25519` lub `~/.ssh/id_rsa`)

**Jak pobrać klucz SSH:**
```bash
cat ~/.ssh/id_ed25519  # Skopiuj całą zawartość
# Lub
cat ~/.ssh/id_rsa
```

### Krok 2: Utwórz workflow w repozytorium landing page

W repozytorium `sowa-landing`, utwórz plik `.github/workflows/deploy.yml`:

```yaml
name: Deploy Landing Page

on:
  push:
    branches: [ main ]
  workflow_dispatch:  # Pozwala na ręczne uruchomienie w GitHub UI

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v4
    
    - name: Deploy to VPS via SSH
      uses: appleboy/ssh-action@master
      with:
        host: ${{ secrets.VPS_HOST }}
        username: ${{ secrets.VPS_USER }}
        key: ${{ secrets.VPS_SSH_KEY }}
        port: 22
        debug: true
        command_timeout: 10m
        script: |
          echo "🚀 Aktualizacja landing page..."
          
          # Przejdź do katalogu repo landing page
          cd ~/landing-page
          
          # Aktualizuj kod z Git
          echo "📥 Pulling latest code..."
          git fetch origin
          git reset --hard origin/main
          
          # Przejdź do katalogu docker-compose landing
          cd ~/stacks/landing
          
          # Rebuild i restart kontenera Next.js
          echo "🔨 Rebuilding Next.js container..."
          docker compose build --no-cache landing
          
          echo "🔄 Restarting landing container..."
          docker compose up -d --force-recreate landing
          
          # Czekaj aż kontener się uruchomi i zbuduje
          echo "⏳ Waiting for container to be ready..."
          sleep 15
          
          # Sprawdź status
          echo "📊 Container status:"
          docker ps | grep landing || echo "⚠️ Container not found!"
          
          echo "📋 Recent logs:"
          docker logs landing --tail 30 || echo "⚠️ Could not get logs"
          
          echo "✅ Deployment completed!"
```

### Krok 3: Commit i push workflow

```bash
git add .github/workflows/deploy.yml
git commit -m "Add GitHub Actions auto-deploy"
git push origin main
```

### Krok 4: Sprawdź działanie

1. Zrób małą zmianę w `index.html`
2. Commit i push:
   ```bash
   git add index.html
   git commit -m "Test auto-deploy"
   git push origin main
   ```
3. Sprawdź status w GitHub: **Actions** → **Deploy Landing Page**
4. Po kilku sekundach landing page powinien się zaktualizować!

### Sprawdzanie statusu deploymentu

- GitHub Actions: https://github.com/pawlo884/sowa-landing/actions
- Możesz też kliknąć na żółtą kropkę obok commita - pokaże status workflow

### Troubleshooting

**Jeśli deployment się nie powiódł:**
- Sprawdź logi w GitHub Actions
- Upewnij się, że secrets są poprawnie skonfigurowane
- Sprawdź czy klucz SSH ma dostęp do VPS: `ssh -i ~/.ssh/id_ed25519 pawel@VPS_HOST`
- Sprawdź czy kontener landing istnieje: `docker ps | grep landing`

## Nginx Configuration (opcjonalnie)

Jeśli potrzebujesz specjalnej konfiguracji nginx, dodaj plik `nginx.conf` do repo. Jeśli go nie ma, zostanie użyty domyślny szablon z:
- Gzip compression
- Security headers
- Cache dla plików statycznych

## Wskazówki

- Używaj relatywnych ścieżek dla obrazów i plików CSS/JS
- Testuj lokalnie przed push
- Możesz użyć GitHub Actions do automatycznego wdrożenia po push (patrz przykład w `ansible/roles/app/templates/github-actions-deploy.yml.j2`)
