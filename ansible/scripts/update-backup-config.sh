#!/bin/bash
# Skrypt do aktualizacji konfiguracji backupów w secrets.yml
# Używa: ./scripts/update-backup-config.sh

set -e

cd "$(dirname "$0")/.." || exit 1

SECRETS_FILE="ansible/inventories/prod/group_vars/secrets.yml"
EXAMPLE_FILE="ansible/inventories/prod/group_vars/secrets.yml.example"

if [ ! -f "$SECRETS_FILE" ]; then
    echo "❌ Plik $SECRETS_FILE nie istnieje!"
    echo "   Skopiuj $EXAMPLE_FILE do $SECRETS_FILE i uzupełnij hasła."
    exit 1
fi

echo "📝 Aktualizuję konfigurację backupów w $SECRETS_FILE"
echo ""

# Sprawdź czy Python3 jest dostępny
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 nie jest zainstalowany!"
    exit 1
fi

# Użyj Pythona do aktualizacji YAML
python3 << 'PYTHON_SCRIPT'
import yaml
import sys
import re

secrets_file = "ansible/inventories/prod/group_vars/secrets.yml"
example_file = "ansible/inventories/prod/group_vars/secrets.yml.example"

# Wczytaj przykładowy plik
with open(example_file, 'r') as f:
    example_data = yaml.safe_load(f)

# Wczytaj rzeczywisty plik
with open(secrets_file, 'r') as f:
    secrets_content = f.read()
    secrets_data = yaml.safe_load(secrets_content)

# Zaktualizuj postgres_backup_instances
if 'postgres_backup_instances' in example_data:
    secrets_data['postgres_backup_instances'] = example_data['postgres_backup_instances']
    print("✅ Zaktualizowano postgres_backup_instances")
    
    # Zapisz zaktualizowany plik
    with open(secrets_file, 'w') as f:
        yaml.dump(secrets_data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
    
    print(f"✅ Zapisano zaktualizowany plik: {secrets_file}")
    print(f"   Liczba backupów: {len(secrets_data['postgres_backup_instances'])}")
else:
    print("❌ Nie znaleziono postgres_backup_instances w pliku przykładowym!")
    sys.exit(1)
PYTHON_SCRIPT

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Konfiguracja backupów zaktualizowana!"
    echo "   Teraz możesz uruchomić: ansible-playbook playbooks/site.yml --tags backups"
else
    echo ""
    echo "❌ Błąd podczas aktualizacji!"
    exit 1
fi

