#!/bin/bash
# Skrypt do sprawdzenia połączenia z VPS

set -e

cd "$(dirname "$0")/.." || exit 1

# Aktywuj lokalny venv, jeśli istnieje (Windows Git Bash)
if [ -f .venv/Scripts/activate ]; then
  # shellcheck disable=SC1091
  source .venv/Scripts/activate
fi

echo "🔍 Sprawdzanie połączenia z VPS..."
echo ""

# Sprawdź czy ansible jest zainstalowany
if ! command -v ansible &> /dev/null; then
    echo "❌ Ansible nie jest zainstalowany!"
    echo "   Aktywuj venv: source .venv/Scripts/activate"
    exit 1
fi

# Przejdź do katalogu ansible
cd ansible || exit 1

# Ping do VPS
echo "📡 Ping do VPS..."
ansible all -m ping

echo ""
echo "✅ VPS odpowiada!"

