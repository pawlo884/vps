#!/bin/bash
# Dry-run - sprawdzenie zmian bez ich wprowadzania

set -e

cd "$(dirname "$0")/.." || exit 1

# Aktywuj lokalny venv, jeśli istnieje (Windows Git Bash)
if [ -f .venv/Scripts/activate ]; then
  # shellcheck disable=SC1091
  source .venv/Scripts/activate
fi

echo "🔍 Dry-run: sprawdzanie zmian przed wprowadzeniem..."
echo ""

# Sprawdź czy ansible jest zainstalowany
if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Ansible nie jest zainstalowany!"
    echo "   Aktywuj venv: source .venv/Scripts/activate"
    exit 1
fi

# Przejdź do katalogu ansible
cd ansible || exit 1

# Uruchom dry-run z diff
ansible-playbook playbooks/site.yml --check --diff

echo ""
echo "✅ Dry-run zakończony!"

