#!/bin/bash
# Skrypt do uruchamiania Ansible playbook

set -e

cd "$(dirname "$0")/.." || exit 1

# Aktywuj lokalny venv, jeśli istnieje (Windows Git Bash)
if [ -f .venv/Scripts/activate ]; then
  # shellcheck disable=SC1091
  source .venv/Scripts/activate
fi

echo "🚀 Uruchamianie Ansible playbook na VPS..."
echo ""

# Sprawdź czy ansible jest zainstalowany
if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Ansible nie jest zainstalowany!"
    echo "   Aktywuj venv: source .venv/Scripts/activate"
    exit 1
fi

# Przejdź do katalogu ansible
cd ansible || exit 1

# Uruchom playbook
ansible-playbook playbooks/site.yml "$@"

echo ""
echo "✅ Zakończono!"

