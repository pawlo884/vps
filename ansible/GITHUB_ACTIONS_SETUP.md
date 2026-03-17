# Konfiguracja CI/CD z GitHub Actions

## Opcja 1: Prosty deploy przez SSH (ZALECANE)

Workflow, który automatycznie:
- Aktualizuje kod na VPS (git pull)
- Przebudowuje i restartuje kontenery Docker

### Krok 1: Dodaj secrets do GitHub

W repozytorium `nc` → Settings → Secrets and variables → Actions, dodaj:

1. **VPS_HOST**: `192.168.50.31` (lub twoja domena jeśli masz)
2. **VPS_USER**: `pawel`
3. **VPS_SSH_KEY**: zawartość klucza prywatnego SSH (`~/.ssh/id_ed25519_wsl`)

### Krok 2: Utwórz workflow w repozytorium `nc`

Skopiuj ten plik do `.github/workflows/deploy-vps.yml`:

```yaml
name: Deploy to VPS

on:
  push:
    branches: [ main ]
  workflow_dispatch:  # Pozwala na ręczne uruchomienie

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - name: Deploy to VPS via SSH
      uses: appleboy/ssh-action@master
      with:
        host: ${{ secrets.VPS_HOST }}
        username: ${{ secrets.VPS_USER }}
        key: ${{ secrets.VPS_SSH_KEY }}
        port: 22
        debug: true
        command_timeout: 20m
        script: |
          echo "🚀 Starting deployment..."
          
          # Aktualizuj kod aplikacji
          cd /home/pawel/apps/nc
          echo "📥 Pulling latest code..."
          git fetch origin
          git reset --hard origin/main
          
          # Przejdź do katalogu docker-compose
          cd /home/pawel/stacks/nc
          
          # Zaktualizuj docker-compose.yml (jeśli zmienił się szablon)
          # Możesz też ręcznie zaktualizować przez Ansible
          
          # Przebuduj i zrestartuj kontenery
          echo "🐳 Rebuilding and restarting containers..."
          docker compose build --no-cache
          docker compose up -d --force-recreate
          
          # Czekaj aż kontener się uruchomi
          echo "⏳ Waiting for container to be ready..."
          sleep 10
          
          # Sprawdź status
          echo "📊 Container status:"
          docker ps | grep nc || echo "⚠️ Container not found!"
          
          echo "📋 Recent logs:"
          docker logs nc --tail 30 || echo "⚠️ Could not get logs"
          
          echo "✅ Deployment completed!"
```

## Opcja 2: Deploy przez Ansible (zaawansowane)

Jeśli chcesz używać Ansible z GitHub Actions, wymaga to:
- Dostępu do repozytorium `vps` (ansible)
- Skonfigurowania dodatkowych secrets

**Zalety opcji 1:**
- ✅ Prostsze - nie wymaga Ansible
- ✅ Szybsze - bezpośrednie połączenie SSH
- ✅ Wszystko w jednym repozytorium

**Zalety opcji 2:**
- ✅ Spójność - używa tego samego procesu co ręczny deploy
- ✅ Więcej kontroli - pełne możliwości Ansible

## Testowanie

Po dodaniu workflow, zrób commit i push do brancha `main`:

```bash
git add .
git commit -m "Test deployment"
git push origin main
```

Sprawdź status w GitHub Actions: https://github.com/pawlo884/nc/actions

